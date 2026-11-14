<#
.SYNOPSIS
    Builds the Senada Windows installer: dist\Senada-Setup-<version>.exe

.DESCRIPTION
    1. creates a build virtualenv (.venv-build) with PySide6 and PyInstaller
    2. renders the app icon (build\senada.ico)
    3. downloads mpv.exe, yt-dlp.exe and deno.exe (build\tools, kept between builds)
    4. freezes Senada with PyInstaller into dist\Senada\ and copies the tools to dist\Senada\bin\
    5. compiles senada.iss with Inno Setup 6 (iscc.exe)

    Code signing: when SENADA_SIGN_PFX, SENADA_SIGN_PFX_BASE64 or SENADA_SIGN_THUMBPRINT is set
    (see sign.ps1), Senada.exe, the installer and the uninstaller are Authenticode-signed.

    Run from any folder:  powershell -ExecutionPolicy Bypass -File packaging\windows\build.ps1

.PARAMETER SkipInstaller
    Stop after step 4 (portable folder only, no Inno Setup needed).
.PARAMETER Python
    Python launcher used to create the build virtualenv (default: "py -3", then "python").
#>
param(
    [switch]$SkipInstaller,
    [string]$Python = ""
)

$ErrorActionPreference = "Stop"
$Here = $PSScriptRoot
$Root = (Resolve-Path (Join-Path $Here "..\..")).Path
$Venv = Join-Path $Here ".venv-build"
$Build = Join-Path $Here "build"
$Dist = Join-Path $Here "dist"
$Tools = Join-Path $Build "tools"

function Step($msg) { Write-Host ":: $msg" -ForegroundColor Cyan }
function Run($exe, [string[]]$argv) {
    & $exe @argv
    if ($LASTEXITCODE -ne 0) { throw "$exe gagal (kode $LASTEXITCODE)" }
}

$Version = [regex]::Match((Get-Content (Join-Path $Root "senada\__init__.py") -Raw), '__version__\s*=\s*"([^"]+)"').Groups[1].Value
if (-not $Version) { throw "Versi tidak ditemukan di senada\__init__.py" }
$SignPs1 = Join-Path $Here "sign.ps1"
$Sign = [bool]($env:SENADA_SIGN_PFX_BASE64 -or $env:SENADA_SIGN_PFX -or $env:SENADA_SIGN_THUMBPRINT)
Step "Membangun Senada $Version$(if ($Sign) { ' (ditandatangani)' } else { ' (tanpa tanda tangan)' })"

# 1. build virtualenv
$Py = Join-Path $Venv "Scripts\python.exe"
if (-not (Test-Path $Py)) {
    Step "Membuat virtualenv build"
    if ($Python) { $launcher = $Python -split " " }
    elseif (Get-Command py -ErrorAction SilentlyContinue) { $launcher = @("py", "-3") }
    else { $launcher = @("python") }
    $rest = @()
    if ($launcher.Count -gt 1) { $rest = $launcher[1..($launcher.Count - 1)] }
    Run $launcher[0] ($rest + @("-m", "venv", $Venv))
}
Run $Py @("-m", "pip", "install", "--quiet", "--upgrade", "pip")
Run $Py @("-m", "pip", "install", "--quiet", "-r", (Join-Path $Here "requirements-build.txt"))

# 2. icon
Step "Membuat ikon"
Run $Py @((Join-Path $Here "make_icon.py"), (Join-Path $Root "data\senada.png"), (Join-Path $Build "senada.ico"))

# 3. mpv + yt-dlp
Step "Menyiapkan mpv, yt-dlp dan deno"
Run $Py @((Join-Path $Here "fetch_tools.py"), $Tools)

# Senada's Last.fm API account (scrobbling): from the build's secrets into senada\_keys.py,
# which git ignores, so it is in the app but never in the repository (see senada\config.py)
$Keys = Join-Path $Root "senada\_keys.py"
if ($env:SENADA_LASTFM_API_KEY -and $env:SENADA_LASTFM_API_SECRET) {
    $lines = @(
        "# written by packaging/windows/build.ps1 from the build's secrets; not in git",
        "LASTFM_API_KEY = `"$($env:SENADA_LASTFM_API_KEY.Trim())`"",
        "LASTFM_API_SECRET = `"$($env:SENADA_LASTFM_API_SECRET.Trim())`""
    )
    [System.IO.File]::WriteAllLines($Keys, $lines)
    Step "Kunci Last.fm dimasukkan"
} elseif (Test-Path $Keys) {
    Step "Kunci Last.fm dari senada\_keys.py"
} else {
    Step "Tanpa kunci Last.fm: hanya Libre.fm untuk scrobbling"
}

# 4. PyInstaller
Step "Membekukan aplikasi dengan PyInstaller"
$AppDir = Join-Path $Dist "Senada"
if (Test-Path $AppDir) { Remove-Item -Recurse -Force $AppDir }
Run $Py @("-m", "PyInstaller", "--noconfirm", "--clean", "--log-level", "WARN",
          "--distpath", $Dist, "--workpath", (Join-Path $Build "pyinstaller"),
          (Join-Path $Here "senada.spec"))
$BinDir = Join-Path $AppDir "bin"
New-Item -ItemType Directory -Force $BinDir | Out-Null
Copy-Item (Join-Path $Tools "*") $BinDir
Copy-Item (Join-Path $Root "LICENSE") $AppDir
if ($Sign) {
    Step "Menandatangani Senada.exe"
    & $SignPs1 (Join-Path $AppDir "Senada.exe")
}
Step "Folder portabel siap: $AppDir"

if ($SkipInstaller) { return }

# 5. Inno Setup
$Iscc = (Get-Command iscc -ErrorAction SilentlyContinue).Source
if (-not $Iscc) {
    $Iscc = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $Iscc) {
    throw "Inno Setup 6 tidak ditemukan. Pasang dengan:  winget install JRSoftware.InnoSetup  (lalu jalankan lagi), atau pakai -SkipInstaller."
}

$Isl = Join-Path $Build "Indonesian.isl"
if (-not (Test-Path $Isl)) {
    try {
        Invoke-WebRequest -UseBasicParsing -OutFile $Isl `
            "https://raw.githubusercontent.com/jrsoftware/issrc/main/Files/Languages/Unofficial/Indonesian.isl"
    } catch {
        Write-Warning "Bahasa Indonesia untuk installer tidak bisa diunduh; installer memakai bahasa Inggris."
    }
}

Step "Mengompilasi installer dengan Inno Setup"
$IsccArgs = @("/Q", "/DAppVersion=$Version")
if ($Sign) {  # Inno replaces $q with a quote and $f with the quoted file to sign
    $IsccArgs += @("/DSign", ('/Ssenadasign=powershell.exe -NoProfile -ExecutionPolicy Bypass -File $q' + $SignPs1 + '$q $f'))
}
Run $Iscc ($IsccArgs + @((Join-Path $Here "senada.iss")))
Step "Selesai: $(Join-Path $Dist "Senada-Setup-$Version.exe")"
