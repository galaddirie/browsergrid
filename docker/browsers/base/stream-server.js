// server.js
// Low-latency multi-client desktop stream over WebSocket using FFmpeg (X11 -> MPEG-TS).
// View in browser with jsmpeg player.

const http = require("http");
const { spawn } = require("child_process");
const WebSocket = require("ws");

// --- Config (env) ---
const PORT = parseInt(process.env.STREAM_SERVER_PORT || "8083", 10);
const DISPLAY = process.env.DISPLAY || ":1";
const WIDTH = process.env.RESOLUTION_WIDTH || "1920";
const HEIGHT = process.env.RESOLUTION_HEIGHT || "1080";
const VIDEO_SIZE = `${WIDTH}x${HEIGHT}`;
const FPS = process.env.STREAM_FPS || "25";
const BITRATE = process.env.STREAM_BITRATE || "2000k"; // overall ballpark
const FFMPEG = process.env.STREAM_FFMPEG_BINARY || "ffmpeg";
const LOG_PREFIX = "[ws-stream]";

// Codec mode: "mpeg1" (fastest CPU) or "h264" (better quality/bitrate)
const CODEC_MODE = (process.env.STREAM_CODEC_MODE || "mpeg1").toLowerCase();
// Backpressure: if a client buffers too much, we drop their connection
const MAX_BUFFERED_BYTES = parseInt(process.env.STREAM_MAX_CLIENT_BUFFER || `${2 * 1024 * 1024}`, 10);

// --- State ---
/** @type {Set<import('ws')>} */
const clients = new Set();
let ffmpeg = null;
let restarting = false;

// --- Logging ---
function log(msg, meta = {}) {
  const extra = Object.keys(meta).length ? " " + JSON.stringify(meta) : "";
  console.log(`${LOG_PREFIX} ${msg}${extra}`);
}

// --- FFmpeg args ---
function ffmpegArgs() {
  // Shared input flags for low latency
  const input = [
    "-loglevel", process.env.STREAM_FFMPEG_LOGLEVEL || "error",
    "-realtime", "1",
    "-fflags", "nobuffer",
    "-flags", "low_delay",
    "-thread_queue_size", "64",
    "-f", "x11grab",
    "-video_size", VIDEO_SIZE,
    "-draw_mouse", process.env.STREAM_DRAW_MOUSE || "1",
    "-framerate", FPS,
    "-i", DISPLAY,
    "-an" // mute (you can add audio if you capture mic/alsa/pulse)
  ];

  if (CODEC_MODE === "h264") {
    // H.264 zerolatency (better compression, slightly higher CPU)
    return input.concat([
      "-c:v", "libx264",
      "-preset", process.env.STREAM_X264_PRESET || "veryfast",
      "-tune", "zerolatency",
      "-pix_fmt", "yuv420p",
      "-profile:v", "baseline",
      "-level", "3.1",
      "-b:v", BITRATE,
      "-maxrate", BITRATE,
      "-bufsize", "2M",
      "-g", String(Math.max(10, Math.floor(Number(FPS) * 1.0))), // ~1s GOP
      "-keyint_min", String(Math.max(10, Math.floor(Number(FPS) * 1.0))),
      "-x264-params", "scenecut=0:open_gop=0",
      "-f", "mpegts",
      "-muxdelay", "0",
      "-muxpreload", "0",
      "pipe:1"
    ]);
  }

  // Default: super fast MPEG1 (jsmpeg native)
  return input.concat([
    "-c:v", "mpeg1video",
    "-b:v", BITRATE,
    "-minrate", BITRATE,
    "-maxrate", BITRATE,
    "-bufsize", "2M",
    "-r", FPS,
    "-g", String(Math.max(10, Math.floor(Number(FPS) * 1.0))), // ~1s GOP
    "-bf", "0",
    "-f", "mpegts",
    "-muxdelay", "0",
    "-muxpreload", "0",
    "pipe:1"
  ]);
}

// --- FFmpeg lifecycle ---
function startEncoder() {
  if (ffmpeg || restarting) return;
  log("Starting FFmpeg", { display: DISPLAY, size: VIDEO_SIZE, fps: FPS, codecMode: CODEC_MODE });

  ffmpeg = spawn(FFMPEG, ffmpegArgs(), { stdio: ["ignore", "pipe", "pipe"] });

  ffmpeg.stdout.on("data", (chunk) => {
    // Broadcast to all clients, drop slow ones
    for (const ws of clients) {
      if (ws.readyState !== WebSocket.OPEN) continue;

      // If a client is too far behind, drop it (prevents global backpressure)
      if (ws.bufferedAmount > MAX_BUFFERED_BYTES) {
        log("Dropping slow client", { buffered: ws.bufferedAmount });
        try { ws.terminate(); } catch {}
        continue;
      }
      try { ws.send(chunk, { binary: true }, () => {}); } catch {}
    }
  });

  ffmpeg.stderr.on("data", (d) => {
    const msg = d.toString();
    // keep logs quiet unless there's something notable
    if (!/past duration/i.test(msg)) log("ffmpeg", { msg: msg.trim() });
  });

  const restart = () => {
    ffmpeg = null;
    if (clients.size > 0) {
      restarting = true;
      setTimeout(() => {
        restarting = false;
        startEncoder();
      }, parseInt(process.env.STREAM_RESTART_DELAY_MS || "800", 10));
    }
  };

  ffmpeg.on("close", (code, signal) => {
    log("FFmpeg exited", { code, signal });
    restart();
  });
  ffmpeg.on("error", (err) => {
    log("FFmpeg failed to spawn", { error: err.message });
    restart();
  });
}

function stopEncoderIfIdle() {
  if (clients.size === 0 && ffmpeg) {
    log("No clients; stopping FFmpeg");
    try { ffmpeg.kill("SIGTERM"); } catch {}
    ffmpeg = null;
  }
}

// --- HTTP server (health + static player) ---
const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
    return res.end(JSON.stringify({ ok: true, clients: clients.size, encoder: !!ffmpeg, mode: CODEC_MODE }));
  }

  if (req.url === "/" || req.url === "/player.html") {
    res.writeHead(200, { "Content-Type": "text/html" });
    return res.end(PLAYER_HTML);
  }

  res.writeHead(404); res.end("Not found");
});

// --- WebSocket for raw TS stream ---
const wss = new WebSocket.Server({ noServer: true });

wss.on("connection", (ws) => {
  clients.add(ws);
  log("Client connected", { clients: clients.size });

  // Heartbeat (keep NATs/load balancers happy)
  ws.isAlive = true;
  ws.on("pong", () => { ws.isAlive = true; });

  ws.on("close", () => {
    clients.delete(ws);
    log("Client disconnected", { clients: clients.size });
    stopEncoderIfIdle();
  });
  ws.on("error", () => {
    clients.delete(ws);
    stopEncoderIfIdle();
  });

  if (!ffmpeg) startEncoder();
});

// Upgrade HTTP -> WS for path /stream
server.on("upgrade", (req, socket, head) => {
  if (req.url !== "/stream") {
    socket.destroy();
    return;
  }
  wss.handleUpgrade(req, socket, head, (ws) => {
    wss.emit("connection", ws, req);
  });
});

// Ping clients every 15s
setInterval(() => {
  for (const ws of clients) {
    if (!ws.isAlive) { try { ws.terminate(); } catch {} continue; }
    ws.isAlive = false;
    try { ws.ping(); } catch {}
  }
}, 15000);

// Start server
server.listen(PORT, () => log("Listening", { port: PORT }));

// Simple inline player for convenience
const PLAYER_HTML = `
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Low-Latency Stream</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      html, body { margin:0; height:100%; background:#0b0b0b; color:#e7e7e7; font:14px/1.4 ui-sans-serif, system-ui; }
      .wrap { display:flex; flex-direction:column; gap:12px; max-width:min(100vw, 1100px); margin:24px auto; padding:0 16px; }
      canvas { width:100%; height:auto; background:#000; border-radius:12px; }
      .row { display:flex; gap:12px; align-items:center; }
      label { opacity:.8; }
      input { background:#111; border:1px solid #222; color:#eee; padding:6px 8px; border-radius:8px; width:100px; }
      button { background:#111; border:1px solid #222; color:#eee; padding:8px 12px; border-radius:10px; cursor:pointer; }
      .pill { padding:2px 8px; border:1px solid #222; border-radius:9999px; font-size:12px; opacity:.8; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="row">
        <div class="pill">Codec: ${CODEC_MODE === "h264" ? "H.264 (zerolatency)" : "MPEG1 (jsmpeg)"} | FPS: ${FPS} | ${VIDEO_SIZE}</div>
        <a href="/health" class="pill" target="_blank">/health</a>
      </div>
      <canvas id="video"></canvas>
      <div class="row">
        <label>WS URL:</label>
        <input id="ws" value="" />
        <button id="play">Play</button>
      </div>
    </div>
    <script src="https://unpkg.com/jsmpeg@0.2.1/jsmpeg.min.js"></script>
    <script>
      const wsInput = document.getElementById('ws');
      const canvas = document.getElementById('video');
      const playBtn = document.getElementById('play');
      wsInput.value = (location.origin.replace(/^http/,'ws')) + '/stream';

      let player = null;
      function play() {
        if (player) { try { player.destroy(); } catch(e) {} }
        player = new JSMpeg.Player(wsInput.value, { canvas, audio: false, videoBufferSize: 1*1024*1024 });
      }
      playBtn.onclick = play;
      // Autoplay on load
      play();
    </script>
  </body>
</html>
`;
