# Senada

Pemutar musik Spotify gratis & tanpa iklan untuk desktop Linux (Wayland/Hyprland & X11). Ditulis dengan Python + Qt Quick (QML) dan memutar audio jernih secara lokal lewat **MPV**.

**Senada** adalah varian mandiri yang dibuat khusus agar Anda dapat menikmati pengalaman mendengarkan Spotify tanpa memerlukan akun Spotify Premium dan tanpa terganggu oleh iklan.

- **100% Gratis & Bebas Iklan**: Tidak butuh langganan Spotify Premium; audio stream di-resolve tanpa iklan.
- **Beranda, Pencarian & Library**: Akses lagu disukai (*Liked Songs*), playlist pribadi, album, artis, dan antrean.
- **Immersive Player**: Tampilan penuh dengan cover bergelombang, dual visualizer (*cava*), dan lirik tersinkron (*LRCLIB*).
- **Warna Aksen Otomatis**: Warna UI menyesuaikan palet warna cover album secara dinamis.
- **Pre-fetching Cerdas**: Lagu berikutnya di antrean disiapkan di latar belakang untuk transisi yang mulus.
- **MPRIS**: Kontrol penuh via `playerctl`, tombol media keyboard, Hyprlock, Waybar, dan widget desktop lainnya.

---

## Perbandingan: Senada vs Nada

| Fitur | Nada | Senada |
| :--- | :--- | :--- |
| **Syarat Akun** | Butuh Spotify Premium | **Akun Spotify Free / Biasa** |
| **Iklan** | Tergantung akun Spotify | **100% Bebas Iklan** |
| **Mesin Audio** | `librespot` (Spotify Connect) | **MPV + YouTube Music Resolver** |
| **Instalasi** | Membutuhkan Rust / Cargo | **Ringan, dependensi native standar** |
| **Lirik & Visualizer** | LRCLIB & Cava | LRCLIB & Cava |
| **Linux Desktop (Wayland/X11)** | Ya | Ya |

---

## Kebutuhan & Persiapan

1. **Akun Spotify Biasa / Free** (tidak perlu Premium).
2. **Spotify Developer Client ID** (gratis, sekali buat):
   - Masuk ke [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) dengan akun Spotify-mu.
   - Klik **Create app**.
   - Isi **App name** dan **Description** bebas (contoh: `Senada Player`).
   - Pada kolom **Redirect URIs**, masukkan:  
     `http://127.0.0.1:8898/login`
   - Pada pilihan **Which API/SDKs are you planning to use?**, centang **Web API**.
   - Centang persetujuan Terms of Service, lalu klik **Save**.
   - Masuk ke menu **User Management**, tambahkan alamat email akun Spotify-mu.
   - Masuk ke menu **Settings** (tab Basic Information), salin **Client ID** (Client Secret **tidak** diperlukan).

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

1. Buka terminal dan ketik `senada`, atau buka melalui app launcher desktop Anda (Rofi, Wofi, tofi, KDE launcher, GNOME, dll.).
2. Masukkan **Client ID** yang sudah disalin dari Spotify Developer Dashboard.
3. Browser akan otomatis terbuka untuk persetujuan akun Spotify. Klik **Setuju / Agree**.
4. Selesai! Senada siap memutar seluruh lagu favorit Anda.

---

## Lisensi

Didistribusikan di bawah lisensi GNU General Public License v3 (GPL-3.0).
