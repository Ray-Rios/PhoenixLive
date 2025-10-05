// Form preservation hook - prevents form data loss during hCaptcha events

import { LiveViewHook, LiveViewElement } from './types/liveview';

interface FormState {
  [name: string]: string;
}

interface FormPreserverData {
  form: HTMLFormElement;
  formState: FormState;
}

interface FormPreserverHook extends LiveViewHook, FormPreserverData {
  preserveFormData(): void;
  restoreFormData(): void;
}

export const FormPreserver: FormPreserverHook = {
  mounted() {
    this.form = this.el as HTMLFormElement;
    this.formState = {};
    
    // Store reference to this hook on the form element for hCaptcha to access
    (this.form as LiveViewElement).phxHook = this;
    
    // Capture initial form data
    this.preserveFormData();
    
    // Add input event listeners to continuously capture form state
    const inputs = this.form.querySelectorAll('input[name]') as NodeListOf<HTMLInputElement>;
    inputs.forEach((input: HTMLInputElement) => {
      input.addEventListener('input', () => {
        this.preserveFormData();
      });
    });
  },
  
  updated(): void {
    // Restore form data after any LiveView update
    this.restoreFormData();
  },
  
  preserveFormData(): void {
    this.formState = {};
    const inputs = this.form.querySelectorAll('input[name]') as NodeListOf<HTMLInputElement>;
    inputs.forEach((input: HTMLInputElement) => {
      if (input.value) {
        this.formState[input.name] = input.value;
      }
    });
  },
  
  restoreFormData(): void {
    if (this.formState && Object.keys(this.formState).length > 0) {
      const inputs = this.form.querySelectorAll('input[name]') as NodeListOf<HTMLInputElement>;
      inputs.forEach((input: HTMLInputElement) => {
        if (this.formState[input.name] !== undefined) {
          input.value = this.formState[input.name];
        }
      });
    }
  }
} as FormPreserverHook;