import { useEffect, useRef, useState } from 'react';

import { Channel } from 'phoenix';

import { getSocket } from '@/lib/phoenix-socket';
import { SessionPoolSummary } from '@/types';

interface UsePoolsChannelProps {
  onPoolCreated?: (pool: SessionPoolSummary) => void;
  onPoolUpdated?: (pool: SessionPoolSummary) => void;
  onPoolDeleted?: (poolId: string) => void;
  onConnect?: () => void;
  onDisconnect?: () => void;
}

export function usePoolsChannel({
  onPoolCreated,
  onPoolUpdated,
  onPoolDeleted,
  onConnect,
  onDisconnect,
}: UsePoolsChannelProps = {}) {
  const channelReference = useRef<Channel | null>(null);
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    const socket = getSocket();
    const channel = socket.channel('pools');

    channelReference.current = channel;
    // TODO: Add types
    channel
      .join()
      .receive('ok', response => {
        console.log('Successfully joined pools channel', response);
        setIsConnected(true);
        onConnect?.();
      })
      .receive('error', response => {
        console.error('Failed to join pools channel', response);
        setIsConnected(false);
      });

    channel.on('pool_created', payload => {
      console.log('Pool created:', payload.pool);
      onPoolCreated?.(payload.pool);
    });

    channel.on('pool_updated', payload => {
      console.log('Pool updated:', payload.pool);
      onPoolUpdated?.(payload.pool);
    });

    channel.on('pool_deleted', payload => {
      console.log('Pool deleted:', payload.pool_id);
      onPoolDeleted?.(payload.pool_id);
    });

    socket.onOpen(() => {
      console.log('Phoenix socket connected');
    });

    socket.onClose(() => {
      console.log('Phoenix socket disconnected');
      setIsConnected(false);
      onDisconnect?.();
    });

    socket.onError(error => {
      console.error('Phoenix socket error:', error);
    });

    return () => {
      if (channelReference.current) {
        channelReference.current.leave();
        channelReference.current = null;
      }
    };
  }, [
    onPoolCreated,
    onPoolUpdated,
    onPoolDeleted,
    onConnect,
    onDisconnect,
  ]);

  return {
    channel: channelReference.current,
    isConnected,
  };
}

