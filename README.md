<div align="center">

<img src="data/senada.png" alt="Logo Senada" width="112">

# Senada

**Pemutar musik gratis, bebas iklan, dan tanpa akun untuk Windows & Linux.**

Katalog dari YouTube Music, library tersimpan di komputermu sendiri, audio diputar langsung lewat MPV.

[![Rilis terbaru](https://img.shields.io/github/v/release/Zeeynrs/Senada-FreeVersion?label=rilis&color=111111)](https://github.com/Zeeynrs/Senada-FreeVersion/releases/latest)
[![Lisensi GPL-3.0](https://img.shields.io/badge/lisensi-GPL--3.0-111111)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11%20%7C%20Linux-111111)

[**Unduh untuk Windows**](#windows-1011) · [**Pasang di Linux**](#linux) · [Tangkapan layar](#tangkapan-layar) · [Fitur](#fitur)

<img src="docs/screenshots/beranda.png" alt="Beranda Senada dengan lirik tersinkron di panel kanan" width="100%">

</div>

---

## Tangkapan Layar

<table>
  <tr>
    <td width="50%"><img src="docs/screenshots/player-imersif.png" alt="Player imersif"><p align="center"><b>Player imersif</b> — sampul di tengah visualizer, lirik tersinkron</p></td>
    <td width="50%"><img src="docs/screenshots/album.png" alt="Halaman album"><p align="center"><b>Album & playlist</b> — tabel lagu yang bisa diurutkan</p></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/screenshots/artis.png" alt="Halaman artis"><p align="center"><b>Halaman artis</b> — lagu populer dan diskografi</p></td>
    <td width="50%"><img src="docs/screenshots/tema-terang.png" alt="Tema terang"><p align="center"><b>Tema terang</b> — ikut sistem atau pilih sendiri</p></td>
  </tr>
  <tr>
    <td colspan="2"><img src="docs/screenshots/efek-kaca.png" alt="Efek kaca dengan sampul album"><p align="center"><b>Efek kaca</b> — sampul album yang diburamkan di balik panel tembus pandang</p></td>
  </tr>
</table>

---

## Fitur

**Tanpa akun, tanpa iklan**
- Buka aplikasi, langsung cari dan putar — tidak perlu Spotify Premium, Client ID, cookie, atau login.
- Audio diputar langsung oleh MPV, jadi pemutar iklan YouTube tidak pernah dimuat.

**Musik**
- Beranda, pencarian, album, artis, dan playlist dari katalog **YouTube Music** (rilis baru, trending, tangga lagu, mix komunitas).
- **Impor dari Spotify**: tempel link playlist/album publik, Senada mencocokkan setiap lagunya di YouTube Music.
- **Radio**: klik kanan lagu → *Putar radio dari lagu ini*.
- **Lirik tersinkron** dari LRCLIB, di panel kanan maupun di player imersif.
- Pre-fetching lagu berikutnya supaya perpindahan lagu cepat.

**Library lokal**
- Lagu disukai, playlist buatan sendiri, album/artis/playlist yang disimpan, dan riwayat putar.
- Semuanya tersimpan di komputermu: `%APPDATA%\Senada\library.json` (Windows) atau `~/.config/senada/library.json` (Linux).

**Tampilan**
- Tema gelap dan terang yang mengikuti sistem (Windows, KDE, GNOME) atau dipilih di Pengaturan.
- Sidebar yang bisa disembunyikan, panel kanan untuk lirik atau antrean, dan daftar lagu berbentuk tabel yang bisa diurutkan per kolom.
- **Player imersif**: sampul bulat di tengah visualizer melingkar (*cava*), equalizer, tempo & pitch, antrean, dan lirik.
- **Efek kaca** (opsional): *Sampul album* (jalan di semua sistem) atau *Transparan* (acrylic di Windows 11, blur Hyprland/KDE).
- Warna aksen otomatis dari sampul lagu.

**Integrasi sistem**
- Windows: installer sekali klik dengan pembaruan otomatis.
- Linux: MPRIS (`playerctl`, tombol media, Hyprlock, Waybar), Wayland/Hyprland dan X11.

---

## Instalasi

### Windows 10/11

1. Unduh **`Senada-Setup-<versi>.exe`** dari halaman [**Releases**](https://github.com/Zeeynrs/Senada-FreeVersion/releases/latest).
2. Jalankan installernya. Kalau muncul *"Windows protected your PC"* (SmartScreen), klik **More info → Run anyway** — peringatan ini muncul karena installer belum ditandatangani dengan sertifikat code signing.
3. Pilih **Install for me only** (tidak perlu hak admin), lalu ikuti wizard sampai selesai.
4. Buka **Senada** dari Start Menu.

Installer sudah berisi semua yang dibutuhkan: Python, PySide6, **mpv**, **yt-dlp**, dan **deno** (JavaScript runtime yang dibutuhkan yt-dlp untuk YouTube). Senada dipasang di `%LOCALAPPDATA%\Programs\Senada`.

**Pembaruan otomatis** — Senada memeriksa rilis terbaru saat dibuka, lalu tiap 6 jam (atau lewat *Pengaturan → Periksa Pembaruan*). Kalau ada versi baru, klik **Perbarui**: installer diunduh dan diperiksa (ukuran & SHA-256), dipasang, lalu Senada terbuka lagi dengan sendirinya.

**Menghapus** — *Settings → Apps → Senada → Uninstall*. Library dan setelan di `%APPDATA%\Senada` tidak ikut terhapus.

### Linux

**Instalasi cepat (semua distro, direkomendasikan):**

```bash
curl -fsSL https://raw.githubusercontent.com/Zeeynrs/Senada-FreeVersion/main/install.sh | bash
```

Skrip ini memasang dependensi lewat package manager distromu (pacman, apt, dnf, zypper, xbps, apk), lalu membuat perintah `senada` dan entri di menu aplikasi. Hapus lagi dengan `./install.sh --uninstall`.

<details>
<summary><b>Clone manual</b></summary>

```bash
git clone https://github.com/Zeeynrs/Senada-FreeVersion.git
cd Senada-FreeVersion
./install.sh
```
</details>

<details>
<summary><b>Arch Linux & turunannya</b> (EndeavourOS, CachyOS, Manjaro, …)</summary>

```bash
git clone https://github.com/Zeeynrs/Senada-FreeVersion.git
cd Senada-FreeVersion
makepkg -si
```
</details>

Jalankan dengan perintah `senada` atau dari app launcher (Rofi, Wofi, tofi, KDE, GNOME, …).

---

## Cara Pakai

1. Buka Senada — langsung masuk ke Beranda, tanpa layar login.
2. **Cari** lagu, artis, album, atau playlist (`Ctrl+F`). Link YouTube Music dan Spotify juga bisa langsung ditempel di kolom pencarian.
3. Tekan **♡** di bilah pemutar untuk menyimpan lagu ke *Lagu yang Disukai*, atau **♡** di halaman album/playlist/artis untuk menyimpannya ke Koleksi.
4. Buat playlist lewat tombol **+** di sidebar, atau klik kanan lagu → *Tambah ke playlist*.

### Pindah dari Spotify

Buka **Koleksimu → Impor**, tempel link playlist atau album **publik** (misalnya `https://open.spotify.com/playlist/...`), lalu klik **Impor**. Playlist muncul di sidebar.

Senada lalu mencocokkan setiap lagu dengan YouTube Music di latar belakang: judul, artis, dan durasi dibandingkan, dan versi lain (live, cover, karaoke, remix, slowed/sped up) dihindari kecuali memang itu yang dicari. Lagu yang pencocokannya kurang yakin diberi tanda **?** — klik tanda itu (atau klik kanan → *Pilih versi lain…*) untuk melihat semua kandidat beserta skornya, mencobanya, dan memilih yang benar. Pilihanmu diingat.

Seluruh isi playlist ikut diimpor (sampai batas Spotify, 10.000 lagu); playlist besar butuh beberapa menit sampai semua lagunya cocok. *Liked Songs* Spotify bersifat privat sehingga tidak bisa diimpor langsung — buat playlist publik berisi lagu-lagu itu, lalu impor link-nya.

### Pintasan keyboard

| Tombol | Aksi |
| :--- | :--- |
| `Space` | Putar / jeda |
| `Ctrl+→` / `Ctrl+←` | Lagu berikutnya / sebelumnya |
| `Ctrl+↑` / `Ctrl+↓` | Volume naik / turun |
| `Ctrl+L` | Buka / tutup player imersif |
| `Ctrl+F` | Cari |
| `Ctrl+B` | Tampilkan / sembunyikan sidebar |
| `Alt+←` / `Alt+→` | Kembali / maju |
| `Ctrl+,` | Pengaturan |
| `Ctrl+Q` | Keluar |

---

## Pemecahan Masalah

**Lagu tidak bisa diputar.** Senada memutar audio dari YouTube lewat `yt-dlp`.
- Kalau muncul *"Sign in to confirm you're not a bot"* atau YouTube diblokir di jaringanmu, coba jaringan lain atau VPN.
- Kalau YouTube baru mengubah sistemnya, perbarui `yt-dlp`:
  - Windows (installer): `"%LOCALAPPDATA%\Programs\Senada\bin\yt-dlp.exe" -U`
  - Linux: lewat package manager distromu, atau `yt-dlp -U`

**Windows menolak membuka installer.** Klik **More info → Run anyway** pada layar SmartScreen.

**Data Senada ada di mana?**

| | Windows | Linux |
| :--- | :--- | :--- |
| Library & setelan | `%APPDATA%\Senada` | `~/.config/senada` |
| Cache | `%LOCALAPPDATA%\Senada\Cache` | `~/.cache/senada` |

---

## Senada vs Nada

| Fitur | Nada | Senada |
| :--- | :--- | :--- |
| **Syarat akun** | Butuh Spotify Premium | **Tanpa akun sama sekali** |
| **Iklan** | Tergantung akun Spotify | **Bebas iklan** |
| **Katalog** | Spotify | **YouTube Music** (+ impor playlist publik Spotify) |
| **Library** | Akun Spotify | **Lokal di perangkat** |
| **Mesin audio** | `librespot` (Spotify Connect) | **MPV + yt-dlp** |
| **Lirik & visualizer** | LRCLIB & Cava | LRCLIB & Cava |

---

## Untuk Pengembang

Senada ditulis dengan Python + Qt Quick (PySide6/QML). Kode aplikasi ada di `senada/`, antarmuka di `qml/`, dan packaging Windows di `packaging/windows/`.

<details>
<summary><b>Menjalankan dari kode sumber di Windows</b></summary>

1. Pasang **Python 3.11+** dari [python.org](https://www.python.org/downloads/) (centang *Add python.exe to PATH*).
2. `git clone https://github.com/Zeeynrs/Senada-FreeVersion.git`
3. Taruh `mpv.exe` dan `yt-dlp.exe` di folder `bin\`, atau pasang lewat [Scoop](https://scoop.sh): `scoop bucket add extras` lalu `scoop install mpv yt-dlp`.
4. Klik dua kali **`senada.bat`**. Saat pertama kali, skrip ini membuat `.venv` dan memasang PySide6.

Versi ini diperbarui lewat tombol *Perbarui* di aplikasi (memakai `git`, butuh Git for Windows). MPRIS tidak tersedia di Windows; visualizer butuh `cava.exe` di `bin\` (opsional).
</details>

<details>
<summary><b>Tes</b></summary>

```bash
python -m unittest discover -s tests
```
</details>

<details>
<summary><b>Membangun installer Windows</b></summary>

Butuh Python 3.11+ dan [Inno Setup 6](https://jrsoftware.org/isinfo.php) (`winget install JRSoftware.InnoSetup`):

```powershell
powershell -ExecutionPolicy Bypass -File packaging\windows\build.ps1
```

Hasilnya `packaging\windows\dist\Senada-Setup-<versi>.exe`. Pakai `-SkipInstaller` untuk folder portabel `dist\Senada\` saja.
</details>

<details>
<summary><b>Merilis versi baru</b></summary>

1. Naikkan `__version__` di `senada/__init__.py`, lalu commit.
2. `git tag v<versi>` dan `git push origin v<versi>`.
3. Workflow [`windows-installer.yml`](.github/workflows/windows-installer.yml) membangun installer dan melampirkannya ke Release. Aplikasi yang sudah terpasang akan menawarkan pembaruan ke versi itu.
</details>

<details>
<summary><b>Code signing (opsional)</b></summary>

Kalau salah satu variabel di bawah di-set, `build.ps1` menandatangani `Senada.exe`, installer, dan uninstaller (SHA-256 + timestamp) lewat `packaging\windows\sign.ps1`:

| Variabel | Isi |
| :--- | :--- |
| `SENADA_SIGN_PFX` | path ke file sertifikat `.pfx` |
| `SENADA_SIGN_PFX_BASE64` | isi `.pfx` dalam base64 (untuk secret GitHub Actions) |
| `SENADA_SIGN_THUMBPRINT` | thumbprint sertifikat di `Cert:\CurrentUser\My` |
| `SENADA_SIGN_PASSWORD` | password `.pfx` |

Di GitHub Actions, tambahkan secret `SENADA_SIGN_PFX_BASE64` dan `SENADA_SIGN_PASSWORD`. Tanpa secret itu installer tetap dibangun, hanya tidak ditandatangani.
</details>

---

## Lisensi

Didistribusikan di bawah [GNU General Public License v3.0](LICENSE).
