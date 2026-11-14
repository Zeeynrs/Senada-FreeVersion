# Maintainer: Zeeynrs <https://github.com/Zeeynrs>
pkgname=senada-music-player-git
_pkgname=senada
pkgver=r7.758ae35
pkgrel=1
pkgdesc="Pemutar musik gratis & tanpa iklan tanpa akun untuk Linux desktop (Wayland/Hyprland) dengan Qt Quick & MPV"
arch=('any')
url="https://github.com/Zeeynrs/Senada"
license=('GPL-3.0-only')
depends=('python' 'pyside6' 'mpv' 'yt-dlp' 'python-dbus' 'python-mutagen' 'cava' 'hicolor-icon-theme')
makedepends=('git')
provides=('senada-music-player')
conflicts=('senada-music-player')
source=("senada-src::git+$url.git")  # its own folder name: "Senada" would clash with senada/ on case-insensitive disks
sha256sums=('SKIP')

pkgver() {
    cd "$srcdir/senada-src"
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
    cd "$srcdir/senada-src"

    install -dm755 "$pkgdir/usr/lib/$_pkgname"
    cp -r senada qml data run.py "$pkgdir/usr/lib/$_pkgname/"

    install -dm755 "$pkgdir/usr/bin"
    cat > "$pkgdir/usr/bin/senada" << 'EOF'
#!/bin/sh
exec python3 -I /usr/lib/senada/run.py "$@"
EOF
    chmod 755 "$pkgdir/usr/bin/senada"

    install -Dm644 data/senada.svg "$pkgdir/usr/share/icons/hicolor/scalable/apps/senada.svg"
    sed "s|@BIN@|/usr/bin/senada|" data/senada.desktop > "$srcdir/senada.desktop"
    install -Dm644 "$srcdir/senada.desktop" "$pkgdir/usr/share/applications/senada.desktop"
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
