pragma Singleton
import QtQuick

// Global navigation bus: any component can ask the shell to open a page or a dialog.
QtObject {
    signal open(string kind, string itemId)
    signal immersive(bool on)
    // playlist dialogs live in the shell so every page can use them
    signal playlistDialog(string mode, string playlistId, string currentName, var tracks)
    signal matchPicker(var track)  // "Pilih versi lain…" for an imported track
    signal shareLyrics(int index)  // lyrics as a picture, from line `index` (-1: the sung line)
    signal findArtist(string names)  // AppShell looks the artist up by name (library.findArtist)

    function go(kind, itemId) {
        if (kind)
            open(kind, itemId || "")
    }
    // the artist page of a song: by its YouTube Music artist id, or by name when it has none
    // (songs imported from Spotify)
    function goArtist(track) {
        if (!track)
            return
        const id = track.artistId || ""
        if (id.indexOf("UC") === 0)
            go("artist", id)
        else if (track.artists)
            findArtist(track.artists)
    }
    function newPlaylist(tracks) { playlistDialog("create", "", "", tracks || []) }
    function renamePlaylist(pid, name) { playlistDialog("rename", pid, name || "", []) }
    function deletePlaylist(pid, name) { playlistDialog("delete", pid, name || "", []) }
}
