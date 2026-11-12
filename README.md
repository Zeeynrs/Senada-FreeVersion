# Senada

Pemutar musik gratis & tanpa iklan untuk desktop Linux (Wayland/Hyprland & X11) dan Windows 10/11. Ditulis dengan Python + Qt Quick (QML) dan memutar audio secara lokal lewat **MPV**.

**Senada tidak butuh akun apa pun**: tidak perlu Spotify Premium, Client ID, cookie, atau login. Katalog musik diambil langsung dari **YouTube Music**, dan library Anda disimpan di komputer sendiri.

- **Tanpa Akun & Bebas Iklan**: buka aplikasi, langsung cari dan putar. Audio diputar langsung oleh MPV, jadi pemutar iklan YouTube tidak pernah dimuat.
- **Beranda, Pencarian, Album, Artis & Playlist**: dari katalog YouTube Music (rilis baru, trending, tangga lagu, mix komunitas).
- **Library Lokal**: lagu disukai, playlist buatan sendiri, album/playlist/artis yang disimpan, dan riwayat putar — semuanya di `~/.config/senada/library.json` (Windows: `%APPDATA%\Senada\library.json`).
- **Impor dari Spotify**: tempel link playlist/album **publik** Spotify, Senada mencocokkan lagunya di YouTube Music. Tanpa login.
- **Radio**: klik kanan lagu → *Putar radio dari lagu ini*.
- **Tampilan monokrom**: bilah atas dengan tombol ← → dan sidebar yang bisa disembunyikan (Ctrl+B); sidebar berisi Beranda, Cari, *Koleksimu* (Lagu disukai, Album, Artis, Playlist, Impor), Pengaturan, dan semua yang tersimpan beserta sampulnya. Daftar lagu berbentuk tabel yang bisa diurutkan per kolom. **Panel kanan** menampilkan lirik tersinkron atau antrean; bilah pemutar di bawah dengan kontrol dan seek bar di tengah. Tema terang/gelap mengikuti sistem (Windows, KDE, GNOME) atau dipilih di Pengaturan; warna utama putih di tema gelap dan hitam di tema terang.
- **Efek kaca (opsional)**: di **Pengaturan → Tema → Efek kaca**. *Sampul album* menaruh sampul lagu yang diburamkan di belakang panel tembus pandang (jalan di semua sistem); *Transparan* membuat jendela tembus pandang sehingga wallpaper terlihat (blur dari sistem: acrylic di Windows 11, blur Hyprland/KDE). Ketebalan kacanya bisa diatur.
- **Immersive Player**: tampilan penuh dengan sampul bulat di tengah visualizer melingkar (*cava*, gaya batang atau gelombang), equalizer, tempo & pitch, antrean, dan lirik tersinkron (*LRCLIB*) di atas sampul yang diburamkan.
- **Warna Aksen Otomatis**, **Pre-fetching** lagu berikutnya, dan **MPRIS** (`playerctl`, tombol media, Hyprlock, Waybar).

---

## Perbandingan: Senada vs Nada

| Fitur | Nada | Senada |
| :--- | :--- | :--- |
| **Syarat Akun** | Butuh Spotify Premium | **Tanpa akun sama sekali** |
| **Iklan** | Tergantung akun Spotify | **Bebas iklan** |
| **Katalog** | Spotify | **YouTube Music** (+ impor playlist publik Spotify) |
| **Library** | Akun Spotify | **Lokal di perangkat** |
| **Mesin Audio** | `librespot` (Spotify Connect) | **MPV + yt-dlp** |
| **Lirik & Visualizer** | LRCLIB & Cava | LRCLIB & Cava |

---

## Cara Penggunaan

1. Buka Senada — langsung masuk ke Beranda, tanpa layar login.
2. **Cari** lagu, artis, album, atau playlist. Anda juga bisa menempel link YouTube Music atau link Spotify di kolom pencarian.
3. Tekan **♡** di bar pemutar untuk menyimpan lagu ke *Lagu yang Disukai*, atau **♡** di halaman album/playlist/artis (atau ♡ di pojok kartu) untuk menyimpannya ke **Koleksi**.
4. Buat playlist sendiri lewat tombol **+** di sidebar, atau klik kanan lagu → *Tambah ke playlist*.

### Pindah dari Spotify
Buka **Koleksi → Impor Spotify** (atau **Pengaturan → Profil & Library → Impor dari Spotify**), tempel link playlist atau album publik (contoh `https://open.spotify.com/playlist/...`), lalu klik **Impor**. Playlist akan muncul di sidebar, di bawah *Playlist*.

Setelah diimpor, Senada mencocokkan setiap lagu dengan YouTube Music di latar belakang: judul, artis, dan durasi dibandingkan, dan versi yang berbeda (live, cover, karaoke, remix, slowed/sped up) dihindari kecuali memang itu yang dicari. Sampul lagu ikut terisi. Lagu yang pencocokannya kurang yakin diberi tanda **?** — klik tanda itu (atau klik kanan → *Pilih versi lain…*) untuk melihat semua kandidat beserta skornya, mencoba memutarnya, dan memilih versi yang benar. Pilihanmu diingat.

Seluruh isi playlist ikut diimpor (sampai batas Spotify, 10.000 lagu), lengkap dengan sampul dan nama album. Playlist besar butuh beberapa menit sampai semua lagunya selesai dicocokkan. Batasan: hanya playlist **publik**. *Lagu yang Disukai* (Liked Songs) Spotify bersifat privat sehingga tidak bisa diimpor otomatis — buat playlist publik berisi lagu-lagu itu di Spotify, lalu impor link-nya.

### Kalau lagu tidak bisa diputar
Senada memutar audio dari YouTube lewat `yt-dlp`. Jika YouTube mengubah sistemnya, perbarui `yt-dlp` (`yt-dlp -U`, lewat package manager distro Anda, atau ganti `yt-dlp.exe` di folder `bin\` di Windows). Jika YouTube diblokir di jaringan Anda, gunakan VPN.

---

## Cara Install (Instalasi)

### Opsi 1: Instalasi Cepat Satu Baris (Semua Distro — Direkomendasikan)

Buka terminal dan jalankan:

```bash
curl -fsSL https://raw.githubusercontent.com/Zeeynrs/Senada-FreeVersion/main/install.sh | bash
```

### Opsi 2: Clone Manual & Skrip `./install.sh`

```bash
git clone https://github.com/Zeeynrs/Senada-FreeVersion.git
cd Senada-FreeVersion
chmod +x install.sh
./install.sh
```

### Opsi 3: Paket Native Arch Linux (`makepkg`)

Bagi pengguna **Arch Linux** dan turunannya (EndeavourOS, CachyOS, Manjaro, dll.):

```bash
git clone https://github.com/Zeeynrs/Senada-FreeVersion.git
cd Senada-FreeVersion
makepkg -si
```

---

### Windows 10/11

1. Pasang **Python 3.11+** dari [python.org](https://www.python.org/downloads/) (centang *Add python.exe to PATH*).
2. Unduh Senada (`git clone https://github.com/Zeeynrs/Senada-FreeVersion.git`, atau *Download ZIP* lalu ekstrak).
3. Siapkan **mpv** dan **yt-dlp**: taruh `mpv.exe` dan `yt-dlp.exe` di folder `bin\` Senada, atau pasang lewat [Scoop](https://scoop.sh): `scoop bucket add extras` lalu `scoop install mpv yt-dlp`.
4. Klik dua kali **`senada.bat`**. Saat pertama kali, skrip ini membuat `.venv` dan memasang PySide6 (butuh internet), lalu membuka Senada.

Catatan Windows: MPRIS (kontrol media Linux) tidak tersedia; visualizer butuh `cava.exe` di `bin\` (opsional). Tombol "Perbarui" di aplikasi memakai `git`, jadi hanya bekerja kalau Senada diunduh dengan `git clone` dan Git for Windows terpasang.

---

## Cara Menjalankan

Linux: ketik `senada` di terminal, atau buka melalui app launcher desktop Anda (Rofi, Wofi, tofi, KDE launcher, GNOME, dll.). Windows: klik dua kali `senada.bat`. Tidak ada langkah login.

---

## Lisensi

Didistribusikan di bawah lisensi GNU General Public License v3 (GPL-3.0).
