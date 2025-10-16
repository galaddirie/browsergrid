import { useEffect, useMemo, useRef, useState } from 'react';

import { Pause, Play, RotateCcw } from 'lucide-react';

import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

const statusLabels = {
  idle: 'Idle',
  connecting: 'Connecting…',
  playing: 'Live',
  error: 'Reconnecting…'
} as const;

const statusColors = {
  idle: 'bg-neutral-400',
  connecting: 'bg-amber-400',
  playing: 'bg-emerald-400',
  error: 'bg-rose-400'
} as const;

type StreamStatus = keyof typeof statusLabels;

type StreamViewerProps = {
  sessionId?: string;
  streamUrl?: string;
  isActive?: boolean;
  className?: string;
};

export function StreamViewer({
  sessionId,
  streamUrl,
  isActive = true,
  className
}: StreamViewerProps) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const reconnectTimer = useRef<number | undefined>(undefined);
  const [status, setStatus] = useState<StreamStatus>('idle');
  const [error, setError] = useState<string | null>(null);

  const resolvedStreamUrl = useMemo(() => {
    if (streamUrl) {
      return streamUrl;
    }
    if (!sessionId) {
      return undefined;
    }
    return `/sessions/${sessionId}/edge/stream`;
  }, [sessionId, streamUrl]);

  useEffect(() => {
    const video = videoRef.current;

    if (!video || !resolvedStreamUrl || !isActive) {
      if (video) {
        video.pause();
        video.removeAttribute('src');
        video.load();
      }
      setStatus('idle');
      if (!isActive) {
        setError(null);
      }
      return undefined;
    }

    let cancelled = false;
    window.clearTimeout(reconnectTimer.current);

    const handleLoadStart = () => setStatus('connecting');
    const handleCanPlay = () => {
      setStatus('playing');
      setError(null);
    };
    const scheduleReconnect = () => {
      window.clearTimeout(reconnectTimer.current);
      reconnectTimer.current = window.setTimeout(() => {
        if (cancelled || !video) {
          return;
        }
        setStatus('connecting');
        video.load();
        void video.play().catch(() => {
          setError('Autoplay blocked. Click play to resume.');
        });
      }, 3000);
    };
    const handleError = () => {
      setStatus('error');
      setError('Stream temporarily unavailable. Retrying…');
      scheduleReconnect();
    };
    const handleStalled = () => {
      setStatus('connecting');
    };

    video.addEventListener('loadstart', handleLoadStart);
    video.addEventListener('canplay', handleCanPlay);
    video.addEventListener('error', handleError);
    video.addEventListener('stalled', handleStalled);

    video.src = resolvedStreamUrl;
    video.currentTime = 0;

    void video.play().catch(() => {
      setStatus('error');
      setError('Autoplay blocked. Click play to resume.');
    });

    return () => {
      cancelled = true;
      window.clearTimeout(reconnectTimer.current);
      video.removeEventListener('loadstart', handleLoadStart);
      video.removeEventListener('canplay', handleCanPlay);
      video.removeEventListener('error', handleError);
      video.removeEventListener('stalled', handleStalled);
      video.pause();
      video.removeAttribute('src');
      video.load();
    };
  }, [resolvedStreamUrl, isActive]);

  const handlePlay = () => {
    const video = videoRef.current;
    if (!video) {
      return;
    }
    setStatus('connecting');
    void video.play().catch(() => {
      setStatus('error');
      setError('Unable to start playback. Please check the session status.');
    });
  };

  const handlePause = () => {
    const video = videoRef.current;
    if (!video) {
      return;
    }
    video.pause();
    setStatus('idle');
  };

  const handleRefresh = () => {
    const video = videoRef.current;
    if (!video || !resolvedStreamUrl) {
      return;
    }
    setStatus('connecting');
    setError(null);
    video.pause();
    video.src = resolvedStreamUrl;
    video.load();
    void video.play().catch(() => {
      setStatus('error');
      setError('Autoplay blocked. Click play to resume.');
    });
  };

  return (
    <div
      id="session-stream-viewer"
      className={cn(
        'relative overflow-hidden rounded-lg border border-neutral-200 bg-neutral-950 text-white shadow-inner',
        'transition-colors duration-300',
        className
      )}
    >
      <div className="absolute left-4 top-4 z-20 flex items-center gap-2 rounded-full bg-neutral-900/80 px-3 py-1 text-xs font-medium backdrop-blur">
        <span
          className={cn('h-2 w-2 rounded-full transition-colors duration-300', statusColors[status])}
          aria-hidden="true"
        />
        <span>{statusLabels[status]}</span>
      </div>

      {(!resolvedStreamUrl || !sessionId) && (
        <div className="absolute inset-0 z-20 flex items-center justify-center bg-neutral-950/80 text-center text-sm text-neutral-200">
          Stream URL unavailable for this session.
        </div>
      )}

      {!isActive && (
        <div className="absolute inset-0 z-20 flex items-center justify-center bg-neutral-950/70 text-center text-sm text-neutral-200">
          Browser session is not currently running.
        </div>
      )}

      <video
        id="session-stream-video"
        ref={videoRef}
        muted
        playsInline
        autoPlay
        controls={false}
        className="aspect-video h-full w-full bg-black object-contain"
      />

      <div className="absolute bottom-4 left-4 z-20 flex items-center gap-2">
        <Button
          type="button"
          size="sm"
          variant="secondary"
          onClick={handlePlay}
          className="flex items-center gap-1 bg-white/10 text-white hover:bg-white/20"
        >
          <Play className="h-3 w-3" />
          Play
        </Button>
        <Button
          type="button"
          size="sm"
          variant="secondary"
          onClick={handlePause}
          className="flex items-center gap-1 bg-white/10 text-white hover:bg-white/20"
        >
          <Pause className="h-3 w-3" />
          Pause
        </Button>
        <Button
          type="button"
          size="sm"
          variant="secondary"
          onClick={handleRefresh}
          className="flex items-center gap-1 bg-white/10 text-white hover:bg-white/20"
        >
          <RotateCcw className="h-3 w-3" />
          Refresh
        </Button>
      </div>

      {error && (
        <div className="absolute bottom-4 right-4 z-20 max-w-xs rounded-md bg-rose-500/20 px-3 py-2 text-xs text-rose-100">
          {error}
        </div>
      )}
    </div>
  );
}
