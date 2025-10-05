// Type definitions for Phoenix LiveView ecosystem

declare module "phoenix" {
  export class Socket {
    constructor(endpoint: string, opts?: any);
    connect(): void;
    disconnect(): void;
    isConnected(): boolean;
    onOpen(callback: () => void): void;
    onClose(callback: (event: CloseEvent) => void): void;
    onError(callback: (error: Event) => void): void;
  }

  export class Channel {
    constructor(topic: string, params: any, socket: Socket);
    join(): void;
    leave(): void;
    on(event: string, callback: (payload: any) => void): void;
    off(event: string): void;
    push(event: string, payload: any): void;
  }
}

declare module "phoenix_live_view" {
  export class LiveSocket {
    constructor(url: string, socket: any, opts?: {
      params?: any;
      hooks?: Record<string, any>;
      uploaders?: any;
      csrf_token?: string;
      metadata?: any;
    });
    
    connect(): void;
    disconnect(): void;
    enableLatencySim(upperBoundMs: number): void;
    disableLatencySim(): void;
    getSocket(): any;
    socket: any;
  }
}

declare module "phoenix_html" {
  // Phoenix HTML doesn't export anything, just side effects
}

declare global {
  interface Window {
    liveSocket: any;
  }
}