import { useEffect, useRef } from 'react';
import { Channel } from 'phoenix';
import { getSocket } from '@/lib/phoenix-socket';
import { Session } from '@/types';

interface UseSessionsChannelProps {
  onSessionCreated?: (session: Session) => void;
  onSessionUpdated?: (session: Session) => void;
  onSessionDeleted?: (sessionId: string) => void;
  onConnect?: () => void;
  onDisconnect?: () => void;
}

export function useSessionsChannel({
  onSessionCreated,
  onSessionUpdated,
  onSessionDeleted,
  onConnect,
  onDisconnect
}: UseSessionsChannelProps = {}) {
  const channelRef = useRef<Channel | null>(null);

  useEffect(() => {
    const socket = getSocket();
    const channel = socket.channel('sessions');

    channelRef.current = channel;
    // TODO: Add types
    channel.join()
      .receive('ok', (response) => {
        console.log('Successfully joined sessions channel', response);
        onConnect?.();
      })
      .receive('error', (response) => {
        console.error('Failed to join sessions channel', response);
      });

    channel.on('session_created', (payload) => {
      console.log('Session created:', payload.session);
      onSessionCreated?.(payload.session);
    });

    channel.on('session_updated', (payload) => {
      console.log('Session updated:', payload.session);
      onSessionUpdated?.(payload.session);
    });

    channel.on('session_deleted', (payload) => {
      console.log('Session deleted:', payload.session_id);
      onSessionDeleted?.(payload.session_id);
    });

    socket.onOpen(() => {
      console.log('Phoenix socket connected');
    });

    socket.onClose(() => {
      console.log('Phoenix socket disconnected');
      onDisconnect?.();
    });

    socket.onError((error) => {
      console.error('Phoenix socket error:', error);
    });

    return () => {
      if (channelRef.current) {
        channelRef.current.leave();
        channelRef.current = null;
      }
    };
  }, [onSessionCreated, onSessionUpdated, onSessionDeleted, onConnect, onDisconnect]);

  return {
    channel: channelRef.current,
    isConnected: channelRef.current?.state === 'joined'
  };
}




