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

## Kebutuhan & Cara Penggunaan

Senada memberikan kebebasan penuh dengan **3 pilihan akses**:

### Metode 1: Mode Tamu (Tanpa Akun & Tanpa Login — Paling Cepat)
1. Buka Senada.
2. Di layar awal, pilih tab **Mode Tamu (Tanpa Login)** lalu klik **Mulai Mendengarkan Sekarang**.
3. Selesai! Anda langsung bisa mencari jutaan lagu, memutar tangga lagu teratas (*Top Hits*), dan menempel link lagu/playlist publik Spotify tanpa perlu akun apa pun.

### Metode 2: Spotify Developer Client ID (Resmi, Permanen & Sinkronisasi Library)
Metode ini menghubungkan akun Spotify Anda agar playlist pribadi dan lagu yang disukai (*Liked Songs*) tersinkronisasi:
1. Masuk ke [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) dengan akun Spotify Anda.
2. Klik **Create app**. Isi nama & deskripsi aplikasi bebas (misal: `Senada Music`).
3. Pada kolom **Redirect URIs**, masukkan: `http://127.0.0.1:8898/login`
4. Centang **Web API** dan persetujuan Terms of Service, lalu klik **Save**.
5. ⚠️ **PENTING (Khusus Akun Free):** Buka tab **User Management** di dashboard aplikasi Anda, masukkan **alamat email akun Spotify Anda** (Langkah ini penting agar akun Free tidak ditolak atau diminta Premium oleh Spotify).
6. Buka tab **Settings** (Basic Information), salin **Client ID** (32 karakter).
7. Tempel di Senada pada tab **Developer Client ID** dan klik **Masuk**. Sesi tersimpan permanen dan otomatis diperbarui.

### Metode 3: Login via Cookie `sp_dc` (Opsional)
1. Buka [open.spotify.com](https://open.spotify.com) di browser dan login.
2. Buka Developer Tools browser (tekan **F12** atau klik kanan > **Inspect**).
3. Masuk ke tab **Application** (Chrome/Brave/Edge) atau **Storage** (Firefox).
4. Di bilah samping, buka **Cookies** > klik `https://open.spotify.com`.
5. Salin nilai cookie bernama **`sp_dc`**, tempel di Senada pada tab **Cookie sp_dc**, lalu klik **Masuk**.

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
