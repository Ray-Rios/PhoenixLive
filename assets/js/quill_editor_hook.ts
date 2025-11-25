/**
 * Quill WYSIWYG Editor Hook for Phoenix LiveView
 * 
 * Provides rich text editing with auto-save and image upload capabilities.
 */

import Quill from 'quill';
// Quill CSS is imported via PostCSS in assets/css/app.css (@import "quill/dist/quill.snow.css"),
// so we must not import it here otherwise esbuild will convert it to a runtime require
// which throws in the browser. Keep CSS imports in PostCSS only.

interface QuillHookConfig {
  autosaveDelay?: number;
  placeholder?: string;
  readOnly?: boolean;
}

const QuillEditorHook = {
  mounted(this: any) {
    const config: QuillHookConfig = {
      autosaveDelay: parseInt(this.el.dataset.autosaveDelay || '30000'),
      placeholder: this.el.dataset.placeholder || 'Start writing...',
      readOnly: this.el.dataset.readonly === 'true'
    };

    // Create Quill editor
    this.quill = new Quill(this.el, {
      theme: 'snow',
      readOnly: config.readOnly,
      placeholder: config.placeholder,
      modules: {
        toolbar: [
          [{ 'header': [1, 2, 3, 4, 5, 6, false] }],
          [{ 'font': [] }],
          [{ 'size': ['small', false, 'large', 'huge'] }],
          ['bold', 'italic', 'underline', 'strike'],
          [{ 'color': [] }, { 'background': [] }],
          [{ 'script': 'sub'}, { 'script': 'super' }],
          [{ 'list': 'ordered'}, { 'list': 'bullet' }],
          [{ 'indent': '-1'}, { 'indent': '+1' }],
          [{ 'direction': 'rtl' }],
          [{ 'align': [] }],
          ['blockquote', 'code-block'],
          ['link', 'image', 'video'],
          ['clean']
        ]
      }
    });

    // Set initial content from hidden input
    const initialContent = this.el.querySelector('input[type="hidden"]')?.value;
    if (initialContent) {
      try {
        const delta = JSON.parse(initialContent);
        this.quill.setContents(delta);
      } catch {
        // If not Delta format, assume HTML
        this.quill.root.innerHTML = initialContent;
      }
    }

    // Handle text changes
    let autosaveTimeout: NodeJS.Timeout;
    this.quill.on('text-change', () => {
      // Get content as Delta (Quill's native format)
      const delta = this.quill.getContents();
      const html = this.quill.root.innerHTML;
      
      // Update hidden input
      const hiddenInput = this.el.querySelector('input[type="hidden"]');
      if (hiddenInput) {
        hiddenInput.value = JSON.stringify(delta);
      }

      // Send change event to LiveView
      this.pushEvent('editor-change', {
        delta: delta,
        html: html,
        text: this.quill.getText()
      });

      // Auto-save with debounce
      if (config.autosaveDelay > 0) {
        clearTimeout(autosaveTimeout);
        autosaveTimeout = setTimeout(() => {
          this.pushEvent('editor-autosave', {
            delta: delta,
            html: html
          });
        }, config.autosaveDelay);
      }
    });

    // Handle image uploads
    const toolbar = this.quill.getModule('toolbar');
    toolbar.addHandler('image', () => {
      this.selectLocalImage();
    });

    // Listen for content updates from LiveView
    this.handleEvent('update-editor-content', ({ content }) => {
      try {
        const delta = typeof content === 'string' ? JSON.parse(content) : content;
        this.quill.setContents(delta, 'silent');
      } catch {
        // If not Delta format, assume HTML
        this.quill.root.innerHTML = content;
      }
    });

    // Listen for read-only mode changes
    this.handleEvent('set-editor-readonly', ({ readonly }) => {
      this.quill.enable(!readonly);
    });
  },

  selectLocalImage(this: any) {
    const input = document.createElement('input');
    input.setAttribute('type', 'file');
    input.setAttribute('accept', 'image/*');
    
    input.onchange = () => {
      const file = input.files?.[0];
      if (file) {
        this.uploadImage(file);
      }
    };

    input.click();
  },

  uploadImage(this: any, file: File) {
    // Create FormData for upload
    const formData = new FormData();
    formData.append('file', file);

    // Show loading indicator
    const range = this.quill.getSelection(true);
    this.quill.insertEmbed(range.index, 'image', '/images/loading.gif');
    this.quill.setSelection(range.index + 1);

    // Send upload event to LiveView
    this.pushEvent('editor-upload-image', {
      filename: file.name,
      size: file.size,
      type: file.type
    });

    // In a real implementation, you'd use LiveView uploads
    // For now, we'll use a placeholder
    this.handleEvent('image-uploaded', ({ url }) => {
      // Replace loading image with actual image
      const range = this.quill.getSelection(true);
      this.quill.deleteText(range.index - 1, 1);
      this.quill.insertEmbed(range.index - 1, 'image', url);
    });
  },

  updated(this: any) {
    // Handle updates if needed
  },

  destroyed(this: any) {
    if (this.quill) {
      this.quill = null;
    }
  }
};

export default QuillEditorHook;
