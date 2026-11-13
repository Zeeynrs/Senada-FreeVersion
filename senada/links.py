"""Web links to the song that is playing, for other apps (MPRIS, Discord)."""


def track_link(state) -> str:
    uri = state.get("uri", "") or ""
    if uri.startswith("yt:track:"):
        return "https://music.youtube.com/watch?v=" + uri.split(":", 2)[2]
    if uri.startswith("spotify:track:"):
        return "https://open.spotify.com/track/" + uri.split(":", 2)[2]
    return ""
