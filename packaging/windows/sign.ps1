<#
.SYNOPSIS
    Authenticode-signs files (Senada.exe, the installer, the uninstaller) with SHA-256 + timestamp.

.DESCRIPTION
    The certificate comes from environment variables, checked in this order:
      SENADA_SIGN_PFX_BASE64   base64 of a .pfx file (for CI secrets)
      SENADA_SIGN_PFX          path to a .pfx file
      SENADA_SIGN_THUMBPRINT   thumbprint of a code-signing certificate in Cert:\CurrentUser\My
    SENADA_SIGN_PASSWORD is the .pfx password; SENADA_SIGN_TIMESTAMP overrides the RFC 3161
    timestamp server (default http://timestamp.digicert.com).

    build.ps1 calls this when one of the certificate variables is set; Inno Setup calls it
    (as sign tool "senadasign") for the installer and uninstaller.
#>
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Files
)

$ErrorActionPreference = "Stop"

if (-not ($env:SENADA_SIGN_PFX_BASE64 -or $env:SENADA_SIGN_PFX -or $env:SENADA_SIGN_THUMBPRINT)) { throw "Tidak ada sertifikat: set SENADA_SIGN_PFX, SENADA_SIGN_PFX_BASE64 atau SENADA_SIGN_THUMBPRINT." }
if (-not $Files) { throw "Penggunaan: sign.ps1 <file> [file...]" }

function Get-SigningCert {
    $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet
    if ($env:SENADA_SIGN_PFX_BASE64) {
        $bytes = [Convert]::FromBase64String($env:SENADA_SIGN_PFX_BASE64)
        return New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($bytes, $env:SENADA_SIGN_PASSWORD, $flags)
    }
    if ($env:SENADA_SIGN_PFX) {
        $path = (Resolve-Path $env:SENADA_SIGN_PFX).Path
        return New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($path, $env:SENADA_SIGN_PASSWORD, $flags)
    }
    $cert = Get-Item "Cert:\CurrentUser\My\$($env:SENADA_SIGN_THUMBPRINT)" -ErrorAction SilentlyContinue
    if (-not $cert) { throw "Sertifikat $($env:SENADA_SIGN_THUMBPRINT) tidak ada di Cert:\CurrentUser\My" }
    return $cert
}

$cert = Get-SigningCert
if (-not $cert.HasPrivateKey) { throw "Sertifikat tidak memiliki private key." }
$timestamp = if ($env:SENADA_SIGN_TIMESTAMP) { $env:SENADA_SIGN_TIMESTAMP } else { "http://timestamp.digicert.com" }

foreach ($file in $Files) {
    $file = $file.Trim('"')
    $sig = $null
    for ($try = 1; $try -le 3 -and -not $sig; $try++) {  # timestamp servers fail now and then
        try {
            $sig = Set-AuthenticodeSignature -FilePath $file -Certificate $cert -HashAlgorithm SHA256 `
                -TimestampServer $timestamp -IncludeChain NotRoot
        } catch {
            if ($try -eq 3) { throw }
            Start-Sleep -Seconds (2 * $try)
        }
    }
    # a self-signed test certificate reports UnknownError (untrusted root) but the file is signed
    $check = Get-AuthenticodeSignature -FilePath $file
    if (-not $check.SignerCertificate -or $check.SignerCertificate.Thumbprint -ne $cert.Thumbprint -or
        $check.Status -eq "HashMismatch") {
        throw "Gagal menandatangani ${file}: $($sig.StatusMessage)"
    }
    Write-Host "  ditandatangani: $(Split-Path $file -Leaf) ($($check.Status))"
}
