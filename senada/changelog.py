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
