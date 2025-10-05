// TypeScript interfaces for Rich Editor

import { LiveViewHook } from './liveview';

export interface RichEditorCommand {
  name: string;
  execute: (textarea: HTMLTextAreaElement, selection?: TextSelection) => void;
}

export interface TextSelection {
  start: number;
  end: number;
  text: string;
}

export interface RichEditorData {
  isFullscreen: boolean;
  isPreviewMode?: boolean;
  currentContainer?: HTMLElement;
  currentTextarea?: HTMLTextAreaElement;
  currentToolbar?: HTMLElement;
}

export interface RichEditorHook extends LiveViewHook, RichEditorData {
  initializeEditor(): void;
  createEditorContainer(): HTMLElement;
  createToolbar(): HTMLElement;
  addEventListeners(textarea: HTMLTextAreaElement, toolbar: HTMLElement, container: HTMLElement): void;
  executeCommand(command: string, textarea: HTMLTextAreaElement): void;
  toggleFullscreen(container: HTMLElement): void;
  togglePreview(textarea: HTMLTextAreaElement, container: HTMLElement): void;
  autoResize(textarea: HTMLTextAreaElement): void;
  getSelection(textarea: HTMLTextAreaElement): TextSelection;
  replaceSelection(textarea: HTMLTextAreaElement, newText: string): void;
  wrapSelection(textarea: HTMLTextAreaElement, before: string, after: string): void;
  renderMarkdown(content: string): string;
}