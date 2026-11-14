"""What changed in each version, shown in Settings → What's new (newest first).

Kept in the app (not fetched) so it works offline and matches the code that is running.
Each entry has the text in English and Indonesian. "next" collects what is on `main` but
not in a release yet (hidden while empty); when releasing, move its lines into an entry
with the new version number and date and leave "next" empty.
"""

CHANGELOG = [
    {
        "version": "next",
        "date": "",
        "en": {
            "new": [
                "Back up and restore (Settings → Profile & Library): liked songs, playlists, saved albums and "
                "artists, history and settings in one file. Restoring adds what is missing, or replaces the "
                "library, and Senada keeps a copy of your library first.",
                "Automatic backups: once a week Senada keeps a copy of your library (the last 5).",
                "Senada opens maximized, and remembers it if you leave the window at its normal size.",
                "Your stats (in the sidebar): minutes listened, plays, top songs and artists, and the minutes per "
                "day or month, for the last 7 or 30 days, this year or all time. Counted on this device only.",
                "Scrobbling (Settings → Scrobbling): the songs you play are added to your Libre.fm profile (and "
                "Last.fm, once this version of Senada has a Last.fm key).",
                "Local files: add your music folders in Settings → Profile & Library and play your own MP3, FLAC "
                "and other files next to YouTube Music, with their tags, covers and .lrc lyrics.",
                "Phone remote (Settings → Phone remote): scan a QR code and control Senada from your phone's "
                "browser on the same Wi-Fi. No app, and off until you switch it on.",
                "Crossfade (Settings → Audio): the next song fades in over the last 1 to 12 seconds of the one "
                "playing.",
            ],
            "fixed": [],
        },
        "id": {
            "new": [
                "Cadangkan dan pulihkan (Pengaturan → Profil & Library): lagu disukai, playlist, album dan artis "
                "tersimpan, riwayat, serta pengaturan dalam satu file. Memulihkan menambahkan yang belum ada, atau "
                "mengganti library, dan Senada menyalin library-mu dulu.",
                "Cadangan otomatis: seminggu sekali Senada menyimpan salinan library-mu (5 terakhir).",
                "Senada terbuka dalam keadaan maximized, dan mengingatnya kalau kamu membiarkan jendela di ukuran biasa.",
                "Statistikmu (di sidebar): menit mendengarkan, jumlah putar, lagu dan artis teratas, serta menit "
                "per hari atau per bulan, untuk 7 atau 30 hari terakhir, tahun ini, atau sepanjang waktu. Dihitung "
                "di perangkat ini saja.",
                "Scrobbling (Pengaturan → Scrobbling): lagu yang kamu putar ditambahkan ke profil Libre.fm-mu (dan "
                "Last.fm, setelah versi Senada ini punya kunci Last.fm).",
                "File lokal: tambahkan folder musikmu di Pengaturan → Profil & Library dan putar file MP3, FLAC, dan "
                "lainnya bersama YouTube Music, lengkap dengan tag, cover, dan lirik .lrc.",
                "Remote HP (Pengaturan → Remote HP): scan kode QR dan kontrol Senada dari browser HP di Wi-Fi yang "
                "sama. Tanpa aplikasi, dan mati sampai kamu nyalakan.",
                "Crossfade (Pengaturan → Audio): lagu berikutnya masuk perlahan di 1 sampai 12 detik terakhir lagu "
                "yang sedang diputar.",
            ],
            "fixed": [],
        },
    },
    {
        "version": "1.0.11",
        "date": "2026-11-14",
        "en": {
            "new": [
                "Windows media controls: the media keys, the volume flyout, the lock screen and headset buttons "
                "now show and control Senada, with the song and its cover.",
                "Icon in the system tray, to switch on in Settings → Appearance: play, pause, skip and quit "
                "from next to the clock, and closing the window can leave Senada playing there.",
                "Sleep timer: the moon in the player bar stops the music after 15 minutes to 2 hours, or at the "
                "end of the song, fading out gently.",
                "Even out loudness: every song plays at about the same volume (Settings → Audio).",
                "Skip silence: long silences at the start or end of a song go by in a flash, with the lyrics "
                "still in time (Settings → Audio).",
                "More lyrics: BetterLyrics and KuGou join LRCLIB, YouTube Music and NetEase, so fewer songs go "
                "without lyrics.",
                "Karaoke word by word: where the lyrics are timed per word, the sung line fills in with the singer "
                "instead of evenly.",
                "Share lyrics: pick up to 8 lines and turn them into a picture with the cover, to copy or save "
                "(the share button under the lyrics).",
                "Romanization or translation under each line (Settings → Lyrics): Japanese and Korean in Latin "
                "letters, English translations from BetterLyrics, and if you switch it on, Google Translate into "
                "the app's language.",
                "The mini player tucked into the top edge of the screen is bigger: a larger cover and title.",
                "The floating player bar takes on the song: its cover, blurred, and its colour from the left, "
                "with rounder corners and a deeper shadow. It now really floats: the pages, the sidebar and the "
                "side panel run on underneath it.",
                "The cinema full view is tidier: the showtimes and the equalizer sit on a glass card beside the "
                "screen, and the screen's light fades softly into the room instead of ending in a hard edge.",
            ],
            "fixed": [
                "Starting Senada while it is already running brings the open window forward instead of starting "
                "a second one.",
                "Play after the last song of the queue starts it again instead of doing nothing.",
                "A maximized window sent to the mini player (Ctrl+M or its button) comes back maximized from "
                "the taskbar or Alt+Tab, not at a smaller size.",
            ],
        },
        "id": {
            "new": [
                "Kontrol media Windows: tombol media, flyout volume, layar kunci, dan tombol headset sekarang "
                "menampilkan dan mengontrol Senada, lengkap dengan lagu dan cover-nya.",
                "Ikon di tray sistem, bisa dinyalakan di Pengaturan → Tampilan: putar, jeda, lewati lagu, dan "
                "keluar dari samping jam, dan menutup jendela bisa membiarkan Senada tetap memutar di sana.",
                "Timer tidur: ikon bulan di player bar menghentikan musik setelah 15 menit sampai 2 jam, atau di "
                "akhir lagu, dengan volume yang mengecil perlahan.",
                "Samakan kerasnya suara: setiap lagu diputar dengan volume yang kurang lebih sama "
                "(Pengaturan → Audio).",
                "Lewati hening: bagian hening yang panjang di awal atau akhir lagu dilewati dalam sekejap, dan "
                "lirik tetap sinkron (Pengaturan → Audio).",
                "Lebih banyak lirik: BetterLyrics dan KuGou bergabung dengan LRCLIB, YouTube Music, dan NetEase, "
                "jadi makin sedikit lagu tanpa lirik.",
                "Karaoke per kata: jika liriknya punya waktu per kata, baris yang dinyanyikan terisi mengikuti "
                "penyanyinya, bukan rata.",
                "Bagikan lirik: pilih hingga 8 baris dan jadikan gambar dengan cover lagunya, untuk disalin atau "
                "disimpan (tombol bagikan di bawah lirik).",
                "Romanisasi atau terjemahan di bawah tiap baris (Pengaturan → Lirik): lirik Jepang dan Korea dalam "
                "huruf Latin, terjemahan bahasa Inggris dari BetterLyrics, dan jika dinyalakan, Google Translate "
                "ke bahasa aplikasi.",
                "Pemutar mini yang terselip di tepi atas layar lebih besar: cover dan judulnya lebih besar.",
                "Player bar mengambang ikut berwarna lagu: cover-nya diburamkan dan warnanya mengalir dari kiri, "
                "dengan sudut lebih bulat dan bayangan lebih dalam. Kini benar-benar mengambang: halaman, sidebar, "
                "dan panel samping mengalir di bawahnya.",
                "Tampilan penuh bioskop lebih rapi: jadwal tayang dan equalizer ada di kartu kaca di samping "
                "layar, dan cahaya layar memudar lembut ke ruangan, bukan berakhir di tepi yang tegas.",
            ],
            "fixed": [
                "Membuka Senada saat sudah berjalan sekarang memunculkan jendela yang sudah terbuka, bukan "
                "menjalankan Senada kedua.",
                "Menekan putar setelah lagu terakhir di antrean selesai sekarang memutarnya lagi, bukan diam saja.",
                "Jendela yang maximized lalu masuk ke pemutar mini (Ctrl+M atau tombolnya) kembali maximized saat "
                "dibuka dari taskbar atau Alt+Tab, bukan mengecil.",
            ],
        },
    },
    {
        "version": "1.0.10",
        "date": "2026-11-14",
        "en": {
            "new": [
                "\"Follow the song\" accent color: the whole app takes the color of the cover that is playing and "
                "changes smoothly with every song.",
                "Lyrics appearance (Settings → Lyrics): size, serif or sans, left or centered, and how the sung "
                "line stands out: brighter, a soft glow, or karaoke that fills it in letter by letter as it is "
                "sung.",
                "Floating player bar (Settings → Appearance → Player bar): a rounded card above the bottom of the "
                "window with a soft shadow.",
                "The mini player tucks into the top edge of the screen like a notch after a few seconds without the "
                "pointer on it (5 to 15, Settings → Appearance → Tuck into the top edge); point at it to bring it "
                "back.",
                "Vinyl record, Poster and Cinema full views: the volume is an upright rail on the right edge of the "
                "screen (drag it, scroll on it, or click the speaker to mute) instead of a bar in the bottom strip.",
                "Poster full view: the lyrics fill the whole column, with the lines already sung fading out above "
                "the pull quote and the lines to come below it, like the body of an article; click a line to go to "
                "it.",
            ],
            "fixed": [],
        },
        "id": {
            "new": [
                "Warna aksen \"Ikuti lagu\": seluruh aplikasi mengambil warna sampul lagu yang sedang diputar dan "
                "berganti halus di setiap lagu.",
                "Tampilan lirik (Pengaturan → Lirik): ukuran, huruf serif atau sans, rata kiri atau tengah, dan "
                "cara baris yang dinyanyikan menonjol: lebih terang, berpendar lembut, atau karaoke yang terisi "
                "huruf demi huruf.",
                "Bilah pemutar mengambang (Pengaturan → Tampilan → Bilah pemutar): kartu membulat di atas tepi "
                "bawah jendela dengan bayangan halus.",
                "Pemutar mini menyatu dengan tepi atas layar seperti notch setelah beberapa detik tanpa kursor di "
                "atasnya (5 sampai 15 detik, Pengaturan → Tampilan → Menyatu dengan tepi atas); arahkan kursor "
                "untuk memunculkannya lagi.",
                "Tampilan penuh Piringan hitam, Poster, dan Bioskop: volume kini berupa rel tegak di tepi kanan "
                "layar (seret, scroll, atau klik ikon speaker untuk membisukan), bukan bilah di strip bawah.",
                "Tampilan penuh Poster: lirik kini mengisi seluruh kolom, dengan baris yang sudah dinyanyikan "
                "memudar di atas kutipan dan baris berikutnya di bawahnya seperti badan artikel; klik sebuah baris "
                "untuk melompat ke sana.",
            ],
            "fixed": [],
        },
    },
    {
        "version": "1.0.9",
        "date": "2026-11-14",
        "en": {
            "new": [
                "Cinema full view: the cover is a wide film still on a screen in a dark room, panned from top to "
                "bottom as the song plays; each song opens with its title credits, the lyrics are the subtitles and "
                "the queue is a board of showtimes with the time each song starts.",
                "Mini player styles (Settings → Appearance → Mini player style): Classic, Sound wave (bars in the "
                "song's colour that move with the music), Running lyrics (the sung line slides in under the title) "
                "and Cover glass (the blurred cover behind the island).",
                "The Search page shows recommendations before you type: songs, artists and albums based on the "
                "songs you play and like, or what is popular right now when you are new.",
                "The Cassette, Radio and Walkman full view styles are gone; if one of them was chosen, the full "
                "view is back to Visualizer. Vinyl record and Poster stay.",
            ],
            "fixed": [
                "Clicking the artist of a song imported from Spotify now opens the artist page (found by name on "
                "YouTube Music); before, nothing happened.",
                "Music videos look sharp in the big full views: their full-size still is used instead of the small "
                "400×225 thumbnail, and the cinema keeps its 16:9 shape instead of cutting it square.",
                "Closing Senada no longer fills its log (Settings → About → Logs) with errors.",
            ],
        },
        "id": {
            "new": [
                "Tampilan penuh Bioskop: sampul menjadi gambar film lebar di layar dalam ruangan gelap, disapu dari "
                "atas ke bawah mengikuti lagu; tiap lagu dibuka dengan kredit judul, liriknya menjadi subtitle, dan "
                "antrean menjadi papan jadwal tayang dengan jam mulai tiap lagu.",
                "Gaya pemutar mini (Pengaturan → Tampilan → Gaya pemutar mini): Klasik, Gelombang suara (batang "
                "berwarna lagu yang bergerak mengikuti musik), Lirik berjalan (baris yang dinyanyikan bergeser "
                "masuk di bawah judul), dan Kaca sampul (sampul yang diburamkan di belakang island).",
                "Halaman Cari langsung menampilkan rekomendasi sebelum mengetik: lagu, artis, dan album berdasarkan "
                "lagu yang kamu putar dan sukai, atau yang sedang populer kalau kamu baru mulai.",
                "Gaya tampilan penuh Kaset, Radio, dan Walkman dihapus; kalau salah satunya sedang dipakai, "
                "tampilan penuh kembali ke Visualizer. Piringan hitam dan Poster tetap ada.",
            ],
            "fixed": [
                "Mengklik nama artis pada lagu yang diimpor dari Spotify kini membuka halaman artisnya (dicari "
                "berdasarkan nama di YouTube Music); sebelumnya tidak terjadi apa-apa.",
                "Video musik kini tajam di tampilan penuh: gambar ukuran penuhnya dipakai, bukan thumbnail kecil "
                "400×225, dan layar bioskop mempertahankan bentuk 16:9-nya alih-alih memotongnya menjadi persegi.",
                "Menutup Senada tidak lagi memenuhi log-nya (Pengaturan → Tentang → Log) dengan pesan error.",
            ],
        },
    },
    {
        "version": "1.0.8",
        "date": "2026-11-14",
        "en": {
            "new": [
                "Cassette full view: the tape winds from the left reel to the right one as the song plays and the reels turn "
                "at a real cassette's pace; the lyrics are written on a ruled paper card with the sung line highlighted. "
                "Click the cassette to pause.",
                "The full view styles are picked from cards with a small drawing of each (Settings → Appearance).",
                "Vinyl full view with nothing open on the right: the title, artist, controls and the next song fill the space.",
                "The queue and the equalizer now match the vinyl and cassette full views: on the turntable the queue fans out "
                "around the record and each equalizer band is a spoke with a knob, next to a pitch fader with 33 / 45 buttons; "
                "on the cassette the queue is a handwritten track list and the equalizer a tape deck panel with LED meters and faders.",
                "Equalizer and tempo settings are kept after closing the panel or Senada, and are the same in every full view style.",
                "The equalizer and tempo now change the sound: the six bands and presets (Bass Boost, Rock, Vocal…) shape the "
                "music as it plays without a break while dragging, and the tempo plays songs faster or slower, with or without "
                "keeping the original pitch. The equalizer starts flat.",
                "Discord Rich Presence (Settings → Discord): your Discord profile shows \"Listening to Senada\" with the song, "
                "artist, cover, a progress bar and a button that opens the song. Off by default.",
                "Seek bar styles (Settings → Appearance → Seek bar): a line, a wave that ripples while the song plays, "
                "a waveform of bars with its own shape for each song, or dots.",
                "Three more full view styles: Poster (the cover large, the title huge and upright beside it, the sung line "
                "as a pull quote), Radio (an old valve radio: the needle runs along the dial with the song, the sung line "
                "glows in the dial, knobs for volume and seeking, a magic eye lamp) and Walkman (a portable cassette player "
                "with working keys, a volume wheel and a bass boost switch). Each has its own queue and equalizer.",
            ],
            "fixed": [],
        },
        "id": {
            "new": [
                "Tampilan penuh kaset: pita berpindah dari gulungan kiri ke kanan mengikuti lagu dan gulungannya berputar "
                "secepat kaset sungguhan; liriknya tertulis di kartu kertas bergaris dengan stabilo di baris yang dinyanyikan. "
                "Klik kasetnya untuk menjeda.",
                "Gaya tampilan penuh dipilih lewat kartu bergambar (Pengaturan → Tampilan).",
                "Tampilan piringan hitam saat panel kanan ditutup: judul, artis, kontrol, dan lagu berikutnya mengisi ruang kosong.",
                "Antrean dan equalizer kini menyesuaikan tampilan piringan hitam dan kaset: di piringan hitam antrean menyebar "
                "mengelilingi piringan dan tiap pita equalizer berupa jari-jari dengan kenop, di samping fader pitch dengan tombol 33 / 45; "
                "di kaset antrean berupa daftar lagu tulisan tangan dan equalizer berupa panel tape deck dengan meter LED dan fader.",
                "Pengaturan equalizer dan tempo tetap tersimpan setelah panel atau Senada ditutup, dan sama di semua gaya tampilan penuh.",
                "Equalizer dan tempo kini benar-benar mengubah suara: enam pita dan presetnya (Bass Boost, Rock, Vokal…) membentuk "
                "musik saat diputar tanpa jeda ketika slider digeser, dan tempo memutar lagu lebih cepat atau lambat, dengan atau "
                "tanpa mempertahankan nada asli. Equalizer dimulai datar.",
                "Discord Rich Presence (Pengaturan → Discord): profil Discord-mu menampilkan \"Listening to Senada\" beserta lagu, "
                "artis, sampul, bilah progres, dan tombol untuk membuka lagunya. Mati secara bawaan.",
                "Gaya bilah progres (Pengaturan → Tampilan → Bilah progres): garis, gelombang yang beriak saat lagu diputar, "
                "bentuk gelombang dari batang-batang yang berbeda untuk tiap lagu, atau titik-titik.",
                "Tiga gaya tampilan penuh baru: Poster (sampul besar, judul raksasa berdiri di sampingnya, baris yang dinyanyikan "
                "sebagai kutipan), Radio (radio tabung lawas: jarum berjalan di skala mengikuti lagu, baris yang dinyanyikan "
                "menyala di skala, kenop volume dan pencari, lampu magic eye) dan Walkman (pemutar kaset portabel dengan tombol "
                "yang berfungsi, roda volume, dan saklar bass boost). Masing-masing punya antrean dan equalizer sendiri.",
            ],
            "fixed": [],
        },
    },
    {
        "version": "1.0.7",
        "date": "2026-11-13",
        "en": {
            "new": [
                "Download songs to listen without internet: right-click a song → Download for offline, the download button "
                "next to the heart in the player bar, or the download button of a playlist, album or Liked Songs for all of them at once. "
                "They gather in the new Offline songs playlist (sidebar, under Liked songs) and play from the file, with their cover and lyrics. "
                "The files are kept in Music\\Senada; Settings → Profile & Library shows how much space they take and opens the folder.",
                "Vinyl full view (Settings → Appearance → Full view style): a record spinning on the left edge with the cover as its label, "
                "a tonearm that follows the song and can be dragged to seek, and the lyrics fanned out around the record.",
                "More lyrics sources: besides LRCLIB, YouTube Music and NetEase. Automatic tries them in turn; "
                "pick one in Settings → Lyrics or with the button under the lyrics.",
            ],
            "fixed": [],
        },
        "id": {
            "new": [
                "Unduh lagu untuk didengarkan tanpa internet: klik kanan lagu → Unduh untuk offline, tombol unduh di samping hati "
                "di bilah pemutar, atau tombol unduh di playlist, album, atau Lagu disukai untuk semua lagunya sekaligus. "
                "Lagunya terkumpul di playlist baru Lagu offline (sidebar, di bawah Lagu disukai) dan diputar dari file, lengkap dengan sampul dan liriknya. "
                "File disimpan di Music\\Senada; Pengaturan → Profil & Library menampilkan ukurannya dan bisa membuka foldernya.",
                "Tampilan penuh piringan hitam (Pengaturan → Tampilan → Gaya tampilan penuh): piringan berputar di sisi kiri dengan sampul sebagai labelnya, "
                "lengan jarum yang mengikuti lagu dan bisa diseret untuk memajukan atau memundurkan, dan lirik yang menyebar mengelilingi piringan.",
                "Sumber lirik bertambah: selain LRCLIB, ada YouTube Music dan NetEase. Otomatis mencobanya bergantian; "
                "pilih salah satu di Pengaturan → Lirik atau lewat tombol di bawah lirik.",
            ],
            "fixed": [],
        },
    },
    {
        "version": "1.0.6",
        "date": "2026-11-13",
        "en": {
            "new": [
                "Import playlists from YouTube Music too: paste a link to a public or unlisted playlist or album "
                "(also a song link copied while playing from a playlist) in Library → Import playlist. The songs play right away, nothing to match.",
            ],
            "fixed": [
                "Media keys, playerctl and bar widgets lost track of songs whose YouTube id has a “-” in it.",
                "The mini player's lyrics open at the line being sung.",
                "Lighter in the background: while Senada is not the window in use it updates the playing position "
                "4 times a second instead of 16 and pauses the little equalizer next to the playing song (about a third less CPU).",
                "The audio engine (mpv) now always ends together with Senada, also after a crash or a forced close; "
                "before, it could stay behind in the background.",
                "When pressing play stayed silent with no message (seen on Windows), Senada now says why: "
                "if the audio engine (mpv) stopped it is reported and started again on the next play, "
                "and a song lookup that hangs is really stopped after 30 seconds instead of waiting forever.",
                "Senada keeps a log (Settings → About → Logs) so a song that won't play can be looked into.",
                "Windows: minimizing works again and the mini player shows; before, the window came straight back "
                "because Windows hid the mini player together with it.",
            ],
        },
        "id": {
            "new": [
                "Impor playlist dari YouTube Music juga: tempel link playlist atau album publik atau tidak publik "
                "(juga link lagu yang disalin saat diputar dari playlist) di Library → Impor playlist. Lagunya langsung bisa diputar tanpa perlu dicocokkan.",
            ],
            "fixed": [
                "Tombol media, playerctl, dan widget bar kehilangan info lagu yang ID YouTube-nya mengandung “-”.",
                "Lirik di pemutar mini langsung terbuka di baris yang sedang dinyanyikan.",
                "Lebih ringan di latar belakang: saat Senada tidak sedang dipakai, posisi lagu diperbarui 4 kali per detik "
                "(bukan 16) dan equalizer kecil di samping lagu yang diputar berhenti bergerak (CPU sekitar sepertiga lebih hemat).",
                "Mesin audio (mpv) kini selalu ikut berhenti bersama Senada, juga setelah crash atau ditutup paksa; "
                "sebelumnya bisa tertinggal berjalan di latar belakang.",
                "Saat tombol putar ditekan tapi tidak ada suara dan tidak ada pesan (terjadi di Windows), Senada kini memberi tahu sebabnya: "
                "kalau mesin audio (mpv) berhenti, itu dilaporkan dan mpv dinyalakan lagi saat putar ditekan, "
                "dan pencarian lagu yang macet benar-benar dihentikan setelah 30 detik, tidak menunggu selamanya.",
                "Senada kini menyimpan log (Pengaturan → Tentang → Log) supaya lagu yang tidak mau diputar bisa diselidiki.",
                "Windows: jendela bisa diminimalkan lagi dan pemutar mini muncul; sebelumnya jendela langsung kembali "
                "karena Windows ikut menyembunyikan pemutar mini bersamanya.",
            ],
        },
    },
    {
        "version": "1.0.5",
        "date": "2026-11-13",
        "en": {
            "new": [
                "Mini player: a small “dynamic island” at the top of the screen while Senada is minimized, with the song, its time, "
                "play / pause and a button back to the app. The arrow opens it wider with the controls and the lyrics. "
                "The button next to full screen (or Ctrl+M) opens it any time; Settings → Appearance turns it off.",
                "What's new: this page, with the version of Senada on this device.",
                "Accent colors are easier to see: the playing song, the open page, the sung lyric line, chosen filters and a soft glow at the top of the pages. "
                "Settings → Appearance → Accent strength turns the glow off.",
            ],
            "fixed": [
                "A song that will not play is tried in another version from YouTube Music, and otherwise skipped, so the queue never gets stuck.",
                "When YouTube limits requests from your network for a while, Senada says so and waits instead of skipping through the whole playlist.",
                "Songs that are not on YouTube Music get a “?” mark in the list: click it to pick a version yourself.",
                "The language dropdown in Settings showed English even when Indonesian was on.",
            ],
        },
        "id": {
            "new": [
                "Pemutar mini: “dynamic island” kecil di atas layar saat Senada diminimalkan, berisi lagu, durasinya, "
                "putar / jeda, dan tombol kembali ke aplikasi. Panahnya membuka island lebih lebar dengan kontrol dan lirik. "
                "Tombol di sebelah layar penuh (atau Ctrl+M) membukanya kapan saja; Pengaturan → Tampilan bisa mematikannya.",
                "Apa yang baru: halaman ini, lengkap dengan versi Senada di perangkat ini.",
                "Warna aksen lebih terasa: lagu yang diputar, halaman yang dibuka, baris lirik yang dinyanyikan, filter yang dipilih, dan cahaya lembut di atas halaman. "
                "Pengaturan → Tampilan → Intensitas aksen bisa mematikan cahayanya.",
            ],
            "fixed": [
                "Lagu yang gagal diputar dicoba dengan versi lain dari YouTube Music, atau dilewati, jadi antrean tidak pernah macet.",
                "Saat YouTube sementara membatasi permintaan dari jaringanmu, Senada memberi tahu dan menunggu, tidak melompati seluruh playlist.",
                "Lagu yang tidak ada di YouTube Music diberi tanda “?” di daftar: klik untuk memilih versinya sendiri.",
                "Dropdown bahasa di Pengaturan menampilkan English walaupun bahasa Indonesia yang aktif.",
            ],
        },
    },
    {
        "version": "1.0.4",
        "date": "2026-11-13",
        "en": {
            "new": [
                "Settings open as a window over the app, with sections and a search box on the left, theme cards and dropdowns.",
                "Accent colors for the logo, play buttons, seek bar and other details: Mint, Indigo, Sky, Aurora, Sunset, Ocean, Forest, Berry, Amber, Rose, Carbon and Chrome.",
            ],
            "fixed": [
                "Touchpad scrolling is smoother: lists keep gliding after you lift your fingers, and follow them a little faster.",
            ],
        },
        "id": {
            "new": [
                "Pengaturan terbuka sebagai jendela di atas aplikasi, dengan kategori dan kolom cari di kiri, kartu tema, dan dropdown.",
                "Warna aksen untuk logo, tombol putar, bilah lagu, dan detail lain: Mint, Indigo, Langit, Aurora, Senja, Samudra, Hutan, Beri, Amber, Mawar, Karbon, dan Krom.",
            ],
            "fixed": [
                "Scroll touchpad lebih halus: daftar terus meluncur setelah jari diangkat dan sedikit lebih cepat mengikuti jari.",
            ],
        },
    },
    {
        "version": "1.0.3",
        "date": "2026-11-13",
        "en": {
            "new": [
                "Two languages: English (default) and Indonesian, switched in Settings without a restart.",
                "The Settings button (and Ctrl+,) closes Settings again.",
            ],
            "fixed": [
                "Music starts much faster (2–3 seconds instead of about 8), and the next song is prepared ahead so changes have no gap.",
                "Repeat one now really plays the song again from the start.",
            ],
        },
        "id": {
            "new": [
                "Dua bahasa: Inggris (bawaan) dan Indonesia, diganti di Pengaturan tanpa mulai ulang.",
                "Tombol Pengaturan (dan Ctrl+,) bisa menutup Pengaturan lagi.",
            ],
            "fixed": [
                "Musik mulai jauh lebih cepat (2–3 detik, sebelumnya sekitar 8), dan lagu berikutnya disiapkan lebih dulu sehingga perpindahan tanpa jeda.",
                "Mode ulangi satu lagu kini benar-benar mengulang lagu dari awal.",
            ],
        },
    },
    {
        "version": "1.0.2",
        "date": "2026-11-13",
        "en": {
            "fixed": [
                "Transparent mode on Windows shows the blurred desktop behind the window instead of a flat grey or black sheet. Windows 10 gets a blur too.",
            ],
        },
        "id": {
            "fixed": [
                "Mode Transparan di Windows kini memperlihatkan desktop yang di-blur di belakang jendela, bukan lembar abu-abu atau hitam. Windows 10 juga mendapat blur.",
            ],
        },
    },
    {
        "version": "1.0.1",
        "date": "2026-11-13",
        "en": {
            "fixed": [
                "Importing a Spotify playlist on Windows no longer fails with “CERTIFICATE_VERIFY_FAILED”.",
            ],
        },
        "id": {
            "fixed": [
                "Impor playlist Spotify di Windows tidak lagi gagal dengan pesan “CERTIFICATE_VERIFY_FAILED”.",
            ],
        },
    },
    {
        "version": "1.0.0",
        "date": "2026-11-12",
        "en": {
            "new": [
                "The first release: no account needed. Music comes from YouTube Music, ad-free, and your library stays on this device.",
                "Import whole Spotify playlists and albums by link; every song is matched to its YouTube Music version.",
                "Glass effect, full-screen player with lyrics, and a Windows installer that updates itself.",
            ],
        },
        "id": {
            "new": [
                "Rilis pertama: tanpa akun. Musik dari YouTube Music tanpa iklan, dan library tersimpan di perangkat ini.",
                "Impor seluruh playlist dan album Spotify lewat link; setiap lagu dicocokkan ke versinya di YouTube Music.",
                "Efek kaca, pemutar layar penuh dengan lirik, dan installer Windows yang memperbarui dirinya sendiri.",
            ],
        },
    },
]

MONTHS = {
    "en": ["January", "February", "March", "April", "May", "June", "July", "August",
           "September", "October", "November", "December"],
    "id": ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus",
           "September", "Oktober", "November", "Desember"],
}


def format_date(iso: str, lang: str) -> str:
    """'2026-11-13' -> '13 November 2026' (month in the language); '' stays ''."""
    try:
        year, month, day = (int(p) for p in iso.split("-"))
        return f"{day} {MONTHS.get(lang, MONTHS['en'])[month - 1]} {year}"
    except (ValueError, IndexError, AttributeError):
        return ""


def entries(lang: str, include_next: bool) -> list[dict]:
    """The changelog in one language: [{version, date, new: [...], fixed: [...]}]."""
    out = []
    for e in CHANGELOG:
        text = e.get(lang) or e["en"]
        if e["version"] == "next" and not (include_next and (text.get("new") or text.get("fixed"))):
            continue
        out.append({"version": e["version"], "date": format_date(e["date"], lang),
                    "new": list(text.get("new", [])), "fixed": list(text.get("fixed", []))})
    return out
