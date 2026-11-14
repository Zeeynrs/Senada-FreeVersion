"""The phone remote's page (see remote.py): one self-contained HTML file, no outside files."""

PAGE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#0b0b0c">
<title>Senada</title>
<style>
  :root { --bg: #0b0b0c; --card: #17171a; --text: #f4f4f5; --dim: #9a9aa2; --accent: #f4f4f5; }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html, body { margin: 0; height: 100%; background: var(--bg); color: var(--text);
    font: 16px/1.4 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  body { display: flex; flex-direction: column; align-items: center; padding: 20px 20px calc(24px + env(safe-area-inset-bottom)); }
  .backdrop { position: fixed; inset: -40px; background-size: cover; background-position: center;
    filter: blur(40px) saturate(1.2) brightness(.45); opacity: .9; z-index: -1; transition: background-image .6s; }
  header { width: 100%; max-width: 440px; display: flex; justify-content: space-between; align-items: center;
    font-size: 13px; color: var(--dim); letter-spacing: .12em; text-transform: uppercase; font-weight: 700; }
  .cover { width: min(78vw, 360px); aspect-ratio: 1; border-radius: 18px; margin: 28px 0 22px;
    background: var(--card) center / cover no-repeat; box-shadow: 0 20px 50px rgba(0,0,0,.55); }
  .meta { width: 100%; max-width: 440px; display: flex; align-items: center; gap: 12px; }
  .meta div { flex: 1; min-width: 0; }
  .title { font-size: 22px; font-weight: 800; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .artist { color: var(--dim); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .bar { width: 100%; max-width: 440px; margin-top: 20px; }
  .track { height: 6px; border-radius: 3px; background: rgba(255,255,255,.18); position: relative; touch-action: none; }
  .fill { position: absolute; inset: 0 auto 0 0; border-radius: 3px; background: var(--accent); width: 0; }
  .times { display: flex; justify-content: space-between; color: var(--dim); font-size: 12px; margin-top: 8px;
    font-variant-numeric: tabular-nums; }
  .controls { width: 100%; max-width: 440px; display: flex; justify-content: space-between; align-items: center; margin-top: 18px; }
  button { background: none; border: 0; color: var(--text); padding: 10px; border-radius: 50%; cursor: pointer; }
  button svg { width: 26px; height: 26px; fill: currentColor; display: block; }
  button.small svg { width: 22px; height: 22px; }
  button.dim { color: var(--dim); }
  button.on { color: var(--accent); }
  button.play { background: var(--text); color: var(--bg); padding: 18px; }
  button.play svg { width: 32px; height: 32px; }
  .volume { width: 100%; max-width: 440px; display: flex; align-items: center; gap: 12px; margin-top: 22px; color: var(--dim); }
  .volume svg { width: 20px; height: 20px; fill: currentColor; flex: none; }
  input[type=range] { flex: 1; accent-color: var(--accent); }
  .empty { color: var(--dim); margin-top: 40vh; text-align: center; }
  .offline { position: fixed; bottom: 16px; left: 50%; transform: translateX(-50%); background: #3a1d1d; color: #ffb4b4;
    padding: 8px 14px; border-radius: 10px; font-size: 13px; display: none; }
</style>
</head>
<body>
<div class="backdrop" id="backdrop"></div>
<header><span>Senada</span><span id="status">Remote</span></header>
<div class="cover" id="cover"></div>
<div class="meta">
  <div><div class="title" id="title">Nothing playing</div><div class="artist" id="artist">Pick a song in Senada</div></div>
  <button class="small dim" id="like" aria-label="Like"><svg viewBox="0 0 24 24"><path id="heart" d="M16.5 3c-1.74 0-3.41.81-4.5 2.09C10.91 3.81 9.24 3 7.5 3 4.42 3 2 5.42 2 8.5c0 3.78 3.4 6.86 8.55 11.54L12 21.35l1.45-1.32C18.6 15.36 22 12.28 22 8.5 22 5.42 19.58 3 16.5 3zm-4.4 15.55-.1.1-.1-.1C7.14 14.24 4 11.39 4 8.5 4 6.5 5.5 5 7.5 5c1.54 0 3.04.99 3.57 2.36h1.87C13.46 5.99 14.96 5 16.5 5c2 0 3.5 1.5 3.5 3.5 0 2.89-3.14 5.74-7.9 10.05z"/></svg></button>
</div>
<div class="bar">
  <div class="track" id="track"><div class="fill" id="fill"></div></div>
  <div class="times"><span id="pos">0:00</span><span id="dur">0:00</span></div>
</div>
<div class="controls">
  <button class="small dim" id="shuffle" aria-label="Shuffle"><svg viewBox="0 0 24 24"><path d="M10.59 9.17 5.41 4 4 5.41l5.17 5.17 1.42-1.41zM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5zm.33 9.41-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.13z"/></svg></button>
  <button id="previous" aria-label="Previous"><svg viewBox="0 0 24 24"><path d="M6 6h2v12H6zm3.5 6 8.5 6V6z"/></svg></button>
  <button class="play" id="toggle" aria-label="Play or pause"><svg viewBox="0 0 24 24"><path id="playIcon" d="M8 5v14l11-7z"/></svg></button>
  <button id="next" aria-label="Next"><svg viewBox="0 0 24 24"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z"/></svg></button>
  <button class="small dim" id="repeat" aria-label="Repeat"><svg viewBox="0 0 24 24"><path id="repeatIcon" d="M7 7h10v3l4-4-4-4v3H5v6h2V7zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2v4z"/></svg></button>
</div>
<div class="volume">
  <svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3A4.5 4.5 0 0 0 14 7.97v8.05c1.48-.73 2.5-2.25 2.5-4.02z"/></svg>
  <input type="range" id="volume" min="0" max="100" value="80" aria-label="Volume">
</div>
<div class="offline" id="offline">Senada is not reachable</div>
<script>
const key = new URLSearchParams(location.search).get("k") || "";
const $ = id => document.getElementById(id);
const PLAY = "M8 5v14l11-7z", PAUSE = "M6 19h4V5H6v14zm8-14v14h4V5h-4z";
const HEART = "M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z";
const HEART_OUTLINE = $("heart").getAttribute("d");
let state = {}, at = 0, dragging = false, volumeBusy = 0;
const fmt = ms => { const s = Math.max(0, Math.round(ms / 1000)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); };
async function send(cmd, value) {
  try { await fetch("/api/cmd?k=" + encodeURIComponent(key), { method: "POST", body: JSON.stringify({ cmd, value }) }); }
  catch (e) {}
  setTimeout(poll, 150);
}
function position() { return state.isPlaying ? Math.min(state.duration, state.position + (Date.now() - at)) : state.position; }
function draw() {
  if (!state.duration) { $("fill").style.width = "0"; return; }
  const p = position();
  if (!dragging) $("fill").style.width = (100 * p / state.duration) + "%";
  $("pos").textContent = fmt(p); $("dur").textContent = fmt(state.duration);
}
async function poll() {
  try {
    const r = await fetch("/api/state?k=" + encodeURIComponent(key), { cache: "no-store" });
    if (!r.ok) throw new Error(r.status);
    state = await r.json(); at = Date.now();
    $("offline").style.display = "none";
  } catch (e) { $("offline").style.display = "block"; return; }
  $("title").textContent = state.hasTrack ? state.name : "Nothing playing";
  $("artist").textContent = state.hasTrack ? state.artists : "Pick a song in Senada";
  const img = state.image ? 'url("' + state.image.replace(/"/g, "%22") + '")' : "none";
  $("cover").style.backgroundImage = img; $("backdrop").style.backgroundImage = img;
  $("playIcon").setAttribute("d", state.isPlaying ? PAUSE : PLAY);
  $("heart").setAttribute("d", state.liked ? HEART : HEART_OUTLINE);
  $("like").className = "small " + (state.liked ? "on" : "dim");
  $("shuffle").className = "small " + (state.shuffle ? "on" : "dim");
  $("repeat").className = "small " + (state.repeat !== "off" ? "on" : "dim");
  if (Date.now() > volumeBusy) $("volume").value = state.volume;
  draw();
}
["toggle", "next", "previous", "shuffle", "repeat", "like"].forEach(id => $(id).onclick = () => send(id));
const track = $("track");
function seekFrom(e) {
  const r = track.getBoundingClientRect();
  return Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)) * (state.duration || 0);
}
track.onpointerdown = e => { dragging = true; track.setPointerCapture(e.pointerId); $("fill").style.width = (100 * seekFrom(e) / (state.duration || 1)) + "%"; };
track.onpointermove = e => { if (dragging) $("fill").style.width = (100 * seekFrom(e) / (state.duration || 1)) + "%"; };
track.onpointerup = e => { dragging = false; if (state.duration) send("seek", Math.round(seekFrom(e))); };
$("volume").oninput = e => { volumeBusy = Date.now() + 1500; send("volume", Number(e.target.value)); };
poll(); setInterval(poll, 1000); setInterval(draw, 250);
</script>
</body>
</html>
"""
