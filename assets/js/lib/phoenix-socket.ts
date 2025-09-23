import { Socket } from 'phoenix';

let socket: Socket | null = null;

export function getSocket(): Socket {
  if (!socket) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';

    socket = new Socket('/socket', {
      params: {
        _csrf_token: csrfToken
      }
    });

    socket.connect();
  }

  return socket;
}

export function disconnectSocket(): void {
  if (socket) {
    socket.disconnect();
    socket = null;
  }
}

export function isSocketConnected(): boolean {
  return socket?.isConnected() || false;
}




