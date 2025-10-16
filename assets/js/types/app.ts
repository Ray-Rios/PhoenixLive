// TypeScript interfaces for app.js

import { LiveViewHook } from './liveview';

export interface QuestGameData {
  players: Record<string, any>;
  currentPlayerId: string;
  questEngine?: any;
}

// TypeScript interfaces for the main app
import type { 
  ThreeSceneState, 
  GameWorldState, 
  InputState, 
  PerformanceMetrics 
} from '../threejs/types';

interface LiveViewHook {
  el: HTMLElement;
  mounted(): void;
  updated?(): void;
  destroyed?(): void;
  pushEvent?(event: string, payload: any): void;
}

export interface QuestGameHook {

export interface MessageReactionsHook extends LiveViewHook {
  setupMessageReactions(): void;
  showReactionButtons(messageEl: HTMLElement): void;
  hideReactionButtons(messageEl: HTMLElement): void;
  addReaction(messageEl: HTMLElement, emoji: string): void;
}

export interface FlashNotificationData {
  hideTimer?: number;
}

export interface FlashNotificationHook extends LiveViewHook, FlashNotificationData {
  hide(): void;
}

export interface LiveSocketInstrumentation {
  connects: number;
  disconnects: number;
  errors: number;
}

export interface StripeEvent {
  detail: {
    public_key: string;
    session_id: string;
  };
}

export interface DownloadFileEvent {
  detail: {
    url: string;
    filename: string;
  };
}

export interface NotificationEvent {
  detail: {
    title: string;
    body: string;
  };
}

declare global {
  interface Window {
    __liveSocketInstr?: LiveSocketInstrumentation;
    Stripe?: (key: string) => any;
  }
}