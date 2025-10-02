import React from 'react';

interface LiveVNCFrameProps {
  sessionId: string;
  liveUrl?: string;
  className?: string;
}

export function LiveVNCFrame({ 
  sessionId, 
  liveUrl,
  className = '' 
}: LiveVNCFrameProps) {
  if (!sessionId || !liveUrl) {
    return (
      <div className={`flex items-center justify-center bg-neutral-100 rounded-lg ${className}`}>
        <div className="text-center text-neutral-600">
          <div className="text-sm font-medium mb-1">Live view not available</div>
          <div className="text-xs">
            {!liveUrl ? 'Session not running or VNC not configured' : 'Session ID missing'}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className={`relative bg-black rounded-lg overflow-hidden ${className}`}>
      <iframe
        src={liveUrl}
        className="w-full h-full border-0"
        allow="fullscreen"
        title={`Live browser session ${sessionId}`}
        style={{ minHeight: '400px' }}
      />
      <div className="absolute top-2 left-2 bg-black/70 text-white text-xs px-2 py-1 rounded">
        Session: {sessionId.slice(0, 8)}...
      </div>
    </div>
  );
}

export default LiveVNCFrame; 