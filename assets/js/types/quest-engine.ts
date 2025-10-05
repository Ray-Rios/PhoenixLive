// TypeScript interfaces for Quest Game Engine

export interface Player {
  id: string;
  x: number;
  y: number;
  color?: string;
  name?: string;
  message?: string;
  message_time?: number;
}

export interface Alien {
  id: string | number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  hp: number;
  maxHp: number;
  size: number;
  lastDamaged: number;
}

export interface Bullet {
  x: number;
  y: number;
  targetX: number;
  targetY: number;
  speed: number;
  created: number;
}

export interface KeyMap {
  [key: string]: boolean;
}

export interface QuestEngineHook {
  pushEvent(event: string, payload: any): void;
}