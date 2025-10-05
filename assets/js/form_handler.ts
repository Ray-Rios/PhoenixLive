// Form handler that prevents LiveView updates from destroying hCaptcha

import { LiveViewHook, LiveViewElement } from './types/liveview';

interface FormData {
  [key: string]: string;
}

interface UserFormData {
  [key: string]: string;
}

interface SubmitData {
  user: UserFormData;
  captcha_token?: string;
}

interface CaptchaEvents {
  captcha_verified_client: (data: { token: string }) => void;
  captcha_error_client: () => void;
}

interface FormHandlerData {
  form: HTMLFormElement;
  formData: FormData;
  captchaToken: string | null;
  inputs: NodeListOf<HTMLInputElement>;
  captchaEvents: CaptchaEvents;
}

interface FormHandlerHook extends LiveViewHook, FormHandlerData {
  handleSubmit(): void;
  updateSubmitButton(): void;
}

export const FormHandler: FormHandlerHook = {
  mounted() {
    this.form = this.el as HTMLFormElement;
    this.formData = {};
    this.captchaToken = null;
    
    // Store reference to this hook on the form element for hCaptcha to access
    (this.form as LiveViewElement).phxHook = this;
    
    // Capture all form inputs
    this.inputs = this.form.querySelectorAll('input');
    
    // Store initial values
    this.inputs.forEach((input: HTMLInputElement) => {
      const name = input.name;
      if (name) {
        this.formData[name] = input.value || '';
      }
    });
    
    // Add event listeners to inputs
    this.inputs.forEach((input: HTMLInputElement) => {
      input.addEventListener('input', (e: Event) => {
        const target = e.target as HTMLInputElement;
        const name = target.name;
        if (name) {
          this.formData[name] = target.value;
        }
      });
    });
    
    // Handle form submission
    this.form.addEventListener('submit', (e: Event) => {
      e.preventDefault();
      this.handleSubmit();
    });
    
    // Listen for captcha events from hCaptcha hook
    this.captchaEvents = {
      captcha_verified_client: ({ token }: { token: string }) => {
        this.captchaToken = token;
        this.updateSubmitButton();
      },
      
      captcha_error_client: () => {
        this.captchaToken = null;
        this.updateSubmitButton();
      }
    };
    
    // Expose event handler for hCaptcha hook
    this.handleEvent = (eventName: string, data: any) => {
      if (this.captchaEvents[eventName as keyof CaptchaEvents]) {
        this.captchaEvents[eventName as keyof CaptchaEvents](data);
      }
    };
    
    this.updateSubmitButton();
  },
  
  handleSubmit(): void {
    // Prepare form data for submission
    const submitData: SubmitData = {
      user: {}
    };
    
    // Extract user fields from form data
    Object.keys(this.formData).forEach((key: string) => {
      if (key.startsWith('user[') && key.endsWith(']')) {
        const fieldName = key.slice(5, -1); // Remove 'user[' and ']'
        submitData.user[fieldName] = this.formData[key];
      }
    });
    
    // Add captcha token if available
    if (this.captchaToken) {
      submitData.captcha_token = this.captchaToken;
    }
    
    // Send to LiveView
    this.pushEvent('form_submit', submitData);
  },
  
  updateSubmitButton(): void {
    const submitBtn = this.form.querySelector('button[type="submit"]') as HTMLButtonElement;
    if (submitBtn) {
      const needsCaptcha = this.el.dataset.requiresCaptcha === 'true';
      const captchaComplete = this.captchaToken !== null;
      
      if (needsCaptcha && !captchaComplete) {
        submitBtn.disabled = true;
        submitBtn.classList.add('opacity-50', 'cursor-not-allowed');
      } else {
        submitBtn.disabled = false;
        submitBtn.classList.remove('opacity-50', 'cursor-not-allowed');
      }
    }
  },
  
  // Handle external updates (like error states)
  updated(): void {
    // Restore form values after LiveView updates
    this.inputs.forEach((input: HTMLInputElement) => {
      const name = input.name;
      if (name && this.formData[name] !== undefined) {
        input.value = this.formData[name];
      }
    });
    
    this.updateSubmitButton();
  }
} as FormHandlerHook;