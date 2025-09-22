// Form handler that prevents LiveView updates from destroying hCaptcha
export const FormHandler = {
  mounted() {
    this.form = this.el;
    this.formData = {};
    this.captchaToken = null;
    
    // Store reference to this hook on the form element for hCaptcha to access
    this.form.phxHook = this;
    
    // Capture all form inputs
    this.inputs = this.form.querySelectorAll('input');
    
    // Store initial values
    this.inputs.forEach(input => {
      const name = input.name;
      if (name) {
        this.formData[name] = input.value || '';
      }
    });
    
    // Add event listeners to inputs
    this.inputs.forEach(input => {
      input.addEventListener('input', (e) => {
        const name = e.target.name;
        if (name) {
          this.formData[name] = e.target.value;
        }
      });
    });
    
    // Handle form submission
    this.form.addEventListener('submit', (e) => {
      e.preventDefault();
      this.handleSubmit();
    });
    
    // Listen for captcha events from hCaptcha hook
    this.captchaEvents = {};
    
    this.captchaEvents.captcha_verified_client = ({ token }) => {
      this.captchaToken = token;
      this.updateSubmitButton();
    };
    
    this.captchaEvents.captcha_error_client = () => {
      this.captchaToken = null;
      this.updateSubmitButton();
    };
    
    // Expose event handler for hCaptcha hook
    this.handleEvent = (eventName, data) => {
      if (this.captchaEvents[eventName]) {
        this.captchaEvents[eventName](data);
      }
    };
    
    this.updateSubmitButton();
  },
  
  handleSubmit() {
    // Prepare form data for submission
    const submitData = {
      user: {}
    };
    
    // Extract user fields from form data
    Object.keys(this.formData).forEach(key => {
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
  
  updateSubmitButton() {
    const submitBtn = this.form.querySelector('button[type="submit"]');
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
  updated() {
    // Restore form values after LiveView updates
    this.inputs.forEach(input => {
      const name = input.name;
      if (name && this.formData[name] !== undefined) {
        input.value = this.formData[name];
      }
    });
    
    this.updateSubmitButton();
  }
};