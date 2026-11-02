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

## Kebutuhan & Cara Login

Senada mendukung **login via Cookie `sp_dc`** sehingga Anda **TIDAK PERLU** membuat Developer App di Spotify Developer Dashboard dan **TIDAK MEMERLUKAN** Spotify Premium.

### Metode 1: Login dengan Cookie `sp_dc` (Paling Mudah & 100% Bebas Blokir)
1. Buka [open.spotify.com](https://open.spotify.com) di browser dan login dengan akun Spotify gratis Anda.
2. Buka Developer Tools browser (tekan **F12** atau klik kanan > **Inspect**).
3. Masuk ke tab **Application** (Chrome/Brave/Edge) atau **Storage** (Firefox).
4. Di bilah samping, buka **Cookies** > klik `https://open.spotify.com`.
5. Salin isi cookie bernama **`sp_dc`**.
6. Buka Senada, pilih **Login via Cookie sp_dc**, lalu tempel dan klik **Masuk**.

*(Sesi cookie ini berlaku hingga 1 tahun dan otomatis diperbarui oleh Senada).*

### Metode 2: Spotify Developer Client ID (Opsional)
Jika Anda memiliki akun Spotify Premium atau aplikasi developer yang sudah disetujui, Anda tetap bisa memilih tab **Developer Client ID** pada layar masuk Senada.

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
