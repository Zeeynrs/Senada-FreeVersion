"""Windows media controls (SMTC): media keys, the volume flyout, the lock screen and Bluetooth
headset buttons see and control Senada. What MPRIS (mpris.py) is on Linux.

Windows gives these controls to a media player object; Senada plays through mpv, so it holds
a silent Windows.Media.Playback.MediaPlayer only to own them, with its automatic handling
turned off. The song, the cover and the play state are written to the controls by hand.
Button presses arrive on a Windows thread pool thread and are passed to the Qt thread by a
queued signal. The app name and icon in the flyout come from the Start menu shortcut, which
the installer gives Senada's AppUserModelID (see main.py and packaging/windows/senada.iss).
"""

import datetime

from PySide6.QtCore import QObject, Qt, Signal

from winrt.windows.foundation import Uri
from winrt.windows.media import (MediaPlaybackStatus, MediaPlaybackType, SystemMediaTransportControlsButton,
                                 SystemMediaTransportControlsTimelineProperties)
from winrt.windows.media.playback import MediaPlayer
from winrt.windows.storage.streams import RandomAccessStreamReference

# the flyout's seek bar runs on its own: a correction now and then is enough (a jump back,
# a new song or a play / pause goes at once)
TIMELINE_EVERY_MS = 5000


def _artists(state: dict) -> str:
    return ", ".join(a.strip() for a in (state.get("artists") or "").split(",") if a.strip())


class MediaControls(QObject):
    _pressed = Signal(int)   # a SystemMediaTransportControlsButton, from a Windows thread
    _seek = Signal(int)      # ms, from a Windows thread

    def __init__(self, player, parent=None):
        super().__init__(parent)
        self.player = player
        self._media = MediaPlayer()
        self._media.command_manager.is_enabled = False  # Senada answers the buttons itself
        self.smtc = self._media.system_media_transport_controls
        self.smtc.is_enabled = True
        self.smtc.is_play_enabled = self.smtc.is_pause_enabled = True
        self.smtc.is_next_enabled = self.smtc.is_previous_enabled = True
        self.smtc.is_stop_enabled = False
        self._pressed.connect(self._on_button, Qt.ConnectionType.QueuedConnection)
        self._seek.connect(self.player.seek, Qt.ConnectionType.QueuedConnection)
        self._tokens = [
            self.smtc.add_button_pressed(lambda _s, args: self._pressed.emit(int(args.button))),
            self.smtc.add_playback_position_change_requested(
                lambda _s, args: self._seek.emit(int(args.requested_playback_position.total_seconds() * 1000))),
        ]
        self._shown = None        # (id, title, artists, album, cover) last written to the controls
        self._status = None
        self._timeline_at = (0, 0)  # (position, duration) last sent
        player.stateChanged.connect(self._on_state)
        player.positionChanged.connect(self._on_position)
        self._on_state()

    # ---- Senada -> Windows ---------------------------------------------------------------

    def _on_state(self):
        s = self.player.state
        if not s.get("hasTrack"):
            self._set_status(MediaPlaybackStatus.STOPPED)
            return
        shown = (s.get("id", ""), s.get("name", ""), _artists(s), s.get("album", ""),
                 s.get("imageLarge") or s.get("image") or "")
        if shown != self._shown:
            self._shown = shown
            self._show_track(*shown[1:])
            self._send_timeline(force=True)
        self._set_status(MediaPlaybackStatus.PLAYING if s.get("isPlaying") else MediaPlaybackStatus.PAUSED)

    def _show_track(self, title, artists, album, cover):
        updater = self.smtc.display_updater
        updater.type = MediaPlaybackType.MUSIC
        music = updater.music_properties
        music.title = title
        music.artist = artists
        music.album_artist = artists
        music.album_title = album
        try:
            updater.thumbnail = RandomAccessStreamReference.create_from_uri(Uri(cover)) if cover.startswith("http") else None
        except (OSError, ValueError, TypeError):  # an address Windows will not take: no cover
            updater.thumbnail = None
        updater.update()

    def _set_status(self, status):
        if status != self._status:
            self._status = status
            self.smtc.playback_status = status
            self._send_timeline(force=True)  # Windows stops / restarts its own clock with it

    def _on_position(self):
        self._send_timeline()

    def _send_timeline(self, force=False):
        s = self.player.state
        duration = int(s.get("durationMs") or 0)
        pos = int(self.player.position or 0)
        last_pos, last_duration = self._timeline_at
        if not force and duration == last_duration and 0 <= pos - last_pos < TIMELINE_EVERY_MS:
            return
        self._timeline_at = (pos, duration)
        timeline = SystemMediaTransportControlsTimelineProperties()
        timeline.start_time = timeline.min_seek_time = datetime.timedelta(0)
        timeline.end_time = timeline.max_seek_time = datetime.timedelta(milliseconds=max(duration, pos))
        timeline.position = datetime.timedelta(milliseconds=pos)
        self.smtc.update_timeline_properties(timeline)

    # ---- Windows -> Senada ---------------------------------------------------------------

    def _on_button(self, button):
        if button == SystemMediaTransportControlsButton.PLAY:
            if not self.player.state.get("isPlaying"):
                self.player.togglePlay()
        elif button == SystemMediaTransportControlsButton.PAUSE:
            if self.player.state.get("isPlaying"):
                self.player.togglePlay()
        elif button == SystemMediaTransportControlsButton.NEXT:
            self.player.next()
        elif button == SystemMediaTransportControlsButton.PREVIOUS:
            self.player.previous()

    def close(self):
        """Take Senada out of the flyout (on quit)."""
        try:
            self.smtc.remove_button_pressed(self._tokens[0])
            self.smtc.remove_playback_position_change_requested(self._tokens[1])
            self.smtc.is_enabled = False
            self._media.close()
        except OSError:
            pass
