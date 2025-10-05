// TypeScript interfaces for Phoenix LiveView hooks

export interface LiveViewHook {
  el: HTMLElement;
  pushEvent(event: string, payload: any): void;
  handleEvent(event: string, callback: (payload: any) => void): void;
  mounted?(): void;
  updated?(): void;
  destroyed?(): void;
}

export interface LiveViewSocket {
  connect(): void;
  disconnect(): void;
  isConnected(): boolean;
}

export interface LiveViewElement extends HTMLElement {
  phxHook?: any;
}