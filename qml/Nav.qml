pragma Singleton
import QtQuick

// Global navigation bus: any component can ask the shell to open a page or a dialog.
QtObject {
    signal open(string kind, string itemId)
    signal immersive(bool on)
    // playlist dialogs live in the shell so every page can use them
    signal playlistDialog(string mode, string playlistId, string currentName, var tracks)
    signal matchPicker(var track)  // "Pilih versi lain…" for an imported track

    function go(kind, itemId) {
        if (kind)
            open(kind, itemId || "")
    }
    function newPlaylist(tracks) { playlistDialog("create", "", "", tracks || []) }
    function renamePlaylist(pid, name) { playlistDialog("rename", pid, name || "", []) }
    function deletePlaylist(pid, name) { playlistDialog("delete", pid, name || "", []) }
}
