declare module 'phoenix' {
  export class Socket {
    constructor(endpoint: string, opts?: any);
    connect(): void;
    disconnect(callback?: () => void, code?: number, reason?: string): void;
    channel(topic: string, params?: any): Channel;
    onOpen(callback: () => void): void;
    onClose(callback: () => void): void;
    onError(callback: (error: any) => void): void;
    onMessage(callback: (msg: any) => any): void;
  }

  export class Channel {
    join(timeout?: number): Push;
    leave(timeout?: number): Push;
    on(event: string, callback: (payload: any) => void): void;
    off(event: string): void;
    push(event: string, payload: any, timeout?: number): Push;
    receive(status: string, callback: (response: any) => void): this;
  }

  export class Push {
    receive(status: string, callback: (response: any) => void): this;
  }
}
