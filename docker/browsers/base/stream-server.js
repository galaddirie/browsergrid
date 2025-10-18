const http = require('http');
const { spawn } = require('child_process');

const PORT = parseInt(process.env.STREAM_SERVER_PORT || '8083', 10);
const DISPLAY = process.env.DISPLAY || ':1';
const WIDTH = process.env.RESOLUTION_WIDTH || '1920';
const HEIGHT = process.env.RESOLUTION_HEIGHT || '1080';
const VIDEO_SIZE = `${WIDTH}x${HEIGHT}`;
const FPS = process.env.STREAM_FPS || '25';
const BITRATE = process.env.STREAM_BITRATE || '1500k';
const MAXRATE = process.env.STREAM_MAXRATE || '2000k';
const BUFSIZE = process.env.STREAM_BUFSIZE || '4000k';
const QUALITY = process.env.STREAM_QUALITY || 'realtime';
const CPU_USED = process.env.STREAM_CPU_USED || '5';
const THREADS = process.env.STREAM_THREADS || '4';
const CODEC = process.env.STREAM_CODEC || 'libvpx';
const FFMPEG = process.env.STREAM_FFMPEG_BINARY || 'ffmpeg';
const LOG_PREFIX = '[stream-server]';

/** @type {Set<import('http').ServerResponse>} */
const clients = new Set();

let ffmpeg = null;
let restarting = false;

function log(message, metadata = {}) {
  const payload = Object.keys(metadata).length ? ` ${JSON.stringify(metadata)}` : '';
  console.log(`${LOG_PREFIX} ${message}${payload}`);
}

function spawnFfmpeg() {
  if (restarting) return;

  log('Starting ffmpeg encoder', {
    display: DISPLAY,
    videoSize: VIDEO_SIZE,
    fps: FPS,
    bitrate: BITRATE,
    codec: CODEC
  });

  ffmpeg = spawn(FFMPEG, [
    '-loglevel', process.env.STREAM_FFMPEG_LOGLEVEL || 'error',
    '-f', 'x11grab',
    '-video_size', VIDEO_SIZE,
    '-draw_mouse', process.env.STREAM_DRAW_MOUSE || '1',
    '-framerate', FPS,
    '-i', DISPLAY,
    '-c:v', CODEC,
    '-quality', QUALITY,
    '-cpu-used', CPU_USED,
    '-b:v', BITRATE,
    '-maxrate', MAXRATE,
    '-bufsize', BUFSIZE,
    '-qmin', process.env.STREAM_QMIN || '10',
    '-qmax', process.env.STREAM_QMAX || '42',
    '-threads', THREADS,
    '-deadline', process.env.STREAM_DEADLINE || 'realtime',
    '-error-resilient', process.env.STREAM_ERROR_RESILIENT || '1',
    '-auto-alt-ref', process.env.STREAM_AUTO_ALT_REF || '0',
    '-lag-in-frames', process.env.STREAM_LAG_IN_FRAMES || '0',
    '-f', 'webm',
    '-'
  ], {
    stdio: ['ignore', 'pipe', 'pipe']
  });

  ffmpeg.stdout.on('data', (chunk) => {
    clients.forEach((res) => {
      if (!res.write(chunk)) {
        res.flushHeaders?.();
      }
    });
  });

  ffmpeg.stderr.on('data', (data) => {
    log('ffmpeg stderr', { message: data.toString() });
  });

  ffmpeg.on('close', (code, signal) => {
    log('ffmpeg exited', { code, signal });
    ffmpeg = null;
    if (clients.size === 0) {
      log('No active clients, delaying encoder restart');
      return;
    }

    restarting = true;
    setTimeout(() => {
      restarting = false;
      spawnFfmpeg();
    }, parseInt(process.env.STREAM_RESTART_DELAY_MS || '1000', 10));
  });

  ffmpeg.on('error', (error) => {
    log('Failed to spawn ffmpeg', { error: error.message });
    ffmpeg = null;
  });
}

function endClient(res) {
  if (!clients.has(res)) return;
  try {
    res.end();
  } catch (error) {
    log('Error ending client response', { error: error.message });
  }
  clients.delete(res);
  log('Client disconnected', { activeClients: clients.size });

  if (clients.size === 0 && ffmpeg) {
    const processToStop = ffmpeg;
    ffmpeg = null;
    processToStop.kill('SIGTERM');
  }
}

const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Range',
      'Access-Control-Max-Age': '86400'
    });
    res.end();
    return;
  }

  if (req.url === '/health') {
    const encoderStatus = Boolean(ffmpeg);
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    });
    res.end(JSON.stringify({ ok: true, encoder: encoderStatus }));
    return;
  }

  if (req.url !== '/stream' || req.method !== 'GET') {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not found');
    return;
  }

  res.writeHead(200, {
    'Content-Type': 'video/webm',
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    Pragma: 'no-cache',
    Expires: '0',
    Connection: 'keep-alive',
    'Access-Control-Allow-Origin': '*'
  });

  res.flushHeaders?.();
  clients.add(res);
  log('Client connected', { activeClients: clients.size });

  req.on('close', () => endClient(res));

  if (!ffmpeg) {
    spawnFfmpeg();
  }
});

server.listen(PORT, () => {
  log('Stream server listening', { port: PORT });
});

process.on('SIGTERM', () => {
  log('Received SIGTERM, shutting down');
  server.close(() => {
    clients.forEach((client) => endClient(client));
    if (ffmpeg) {
      ffmpeg.kill('SIGTERM');
    }
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  process.emit('SIGTERM');
});
