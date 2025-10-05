// TypeScript interfaces for hCaptcha integration

export interface HCaptchaAPI {
  render(container: HTMLElement, config: HCaptchaConfig): string;
  remove(widgetId: string): void;
  setData?(widgetId: string, data: { 'h-captcha-response': string }): void;
}

export interface HCaptchaConfig {
  sitekey: string;
  callback?: (token: string) => void;
  'error-callback'?: () => void;
  'expired-callback'?: () => void;
  'chalexpired-callback'?: () => void;
  theme?: 'light' | 'dark';
  size?: 'normal' | 'compact';
}

export interface FormHandlerHook {
  handleEvent(eventName: string, data: any): void;
  preserveFormData?(): void;
}

export interface LiveViewElement extends HTMLElement {
  phxHook?: any;
}

declare global {
  interface Window {
    hcaptcha?: HCaptchaAPI;
    hCaptchaLoaded?: () => void;
    liveSocket?: {
      hooks?: Record<string, any>;
    };
  }
}