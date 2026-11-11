# Senada

Pemutar musik gratis & tanpa iklan untuk desktop Linux (Wayland/Hyprland & X11). Ditulis dengan Python + Qt Quick (QML) dan memutar audio secara lokal lewat **MPV**.

**Senada tidak butuh akun apa pun**: tidak perlu Spotify Premium, Client ID, cookie, atau login. Katalog musik diambil langsung dari **YouTube Music**, dan library Anda disimpan di komputer sendiri.

- **Tanpa Akun & Bebas Iklan**: buka aplikasi, langsung cari dan putar. Audio diputar langsung oleh MPV, jadi pemutar iklan YouTube tidak pernah dimuat.
- **Beranda, Pencarian, Album, Artis & Playlist**: dari katalog YouTube Music (rilis baru, trending, tangga lagu, mix komunitas).
- **Library Lokal**: lagu disukai, playlist buatan sendiri, album/playlist/artis yang disimpan, dan riwayat putar — semuanya di `~/.config/senada/library.json`.
- **Impor dari Spotify**: tempel link playlist/album **publik** Spotify, Senada mencocokkan lagunya di YouTube Music. Tanpa login.
- **Radio**: klik kanan lagu → *Putar radio dari lagu ini*.
- **Immersive Player**: tampilan penuh dengan cover bergelombang, dual visualizer (*cava*), dan lirik tersinkron (*LRCLIB*).
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
3. Tekan **♡** di bar pemutar untuk menyimpan lagu ke *Lagu yang Disukai*, atau **♡** di halaman album/playlist/artis untuk menyimpannya ke Library (sidebar).
4. Buat playlist sendiri lewat tombol **+** di sidebar, atau klik kanan lagu → *Tambah ke playlist*.

### Pindah dari Spotify
Buka **Pengaturan → Profil & Library → Impor dari Spotify**, tempel link playlist atau album publik (contoh `https://open.spotify.com/playlist/...`), lalu klik **Impor**. Playlist akan muncul di sidebar.

Batasan: hanya playlist **publik**, dan Spotify hanya menampilkan sekitar 100 lagu pertama per playlist lewat halaman publiknya. *Lagu yang Disukai* (Liked Songs) Spotify bersifat privat sehingga tidak bisa diimpor otomatis — buat playlist publik berisi lagu-lagu itu di Spotify, lalu impor link-nya.

### Kalau lagu tidak bisa diputar
Senada memutar audio dari YouTube lewat `yt-dlp`. Jika YouTube mengubah sistemnya, perbarui `yt-dlp` (`yt-dlp -U`, atau lewat package manager distro Anda). Jika YouTube diblokir di jaringan Anda, gunakan VPN.

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

## Cara Menjalankan

Ketik `senada` di terminal, atau buka melalui app launcher desktop Anda (Rofi, Wofi, tofi, KDE launcher, GNOME, dll.). Tidak ada langkah login.

---

## Lisensi

Didistribusikan di bawah lisensi GNU General Public License v3 (GPL-3.0).
