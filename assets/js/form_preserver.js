// Form preservation hook - prevents form data loss during hCaptcha events
export const FormPreserver = {
  mounted() {
    this.form = this.el;
    this.formState = {};
    
    // Store reference to this hook on the form element for hCaptcha to access
    this.form.phxHook = this;
    
    // Capture initial form data
    this.preserveFormData();
    
    // Add input event listeners to continuously capture form state
    const inputs = this.form.querySelectorAll('input[name]');
    inputs.forEach(input => {
      input.addEventListener('input', () => {
        this.preserveFormData();
      });
    });
  },
  
  updated() {
    // Restore form data after any LiveView update
    this.restoreFormData();
  },
  
  preserveFormData() {
    this.formState = {};
    const inputs = this.form.querySelectorAll('input[name]');
    inputs.forEach(input => {
      if (input.value) {
        this.formState[input.name] = input.value;
      }
    });
  },
  
  restoreFormData() {
    if (this.formState && Object.keys(this.formState).length > 0) {
      const inputs = this.form.querySelectorAll('input[name]');
      inputs.forEach(input => {
        if (this.formState[input.name] !== undefined) {
          input.value = this.formState[input.name];
        }
      });
    }
  }
};