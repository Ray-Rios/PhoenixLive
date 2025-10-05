// Blog autosave hook - TypeScript version

import { LiveViewHook } from './types/liveview';

interface BlogPost {
  [key: string]: string;
}

interface BlogAutosaveData {
  timer: number | null;
  form: HTMLFormElement;
  lastData: string;
}

interface BlogAutosaveHook extends LiveViewHook, BlogAutosaveData {
  extractPostData(form: HTMLFormElement): BlogPost;
}

export const BlogAutosave: BlogAutosaveHook = {
  mounted() {
    const form = this.el as HTMLFormElement;
    this.form = form;
    
    const contentField = form.querySelector('[name="post[content]"]') as HTMLInputElement | HTMLTextAreaElement;
    this.lastData = contentField?.value || '';
    
    const timer = window.setInterval(() => {
      const currentContentField = this.form.querySelector('[name="post[content]"]') as HTMLInputElement | HTMLTextAreaElement;
      const currentData = currentContentField?.value || '';
      
      if (currentData !== this.lastData && currentData.trim() !== '') {
        this.lastData = currentData;
        const post = this.extractPostData(this.form);
        this.pushEvent('autosave_draft', { post });
      }
    }, 10000); // Auto-save every 10 seconds
    
    this.timer = timer;
  },
  
  extractPostData(form: HTMLFormElement): BlogPost {
    const formData = new FormData(form);
    const post: BlogPost = {};
    
    for (const [key, value] of formData.entries()) {
      if (key.startsWith('post[') && typeof value === 'string') {
        const fieldName = key.slice(5, -1); // Remove 'post[' and ']'
        post[fieldName] = value;
      }
    }
    
    return post;
  },
  
  destroyed() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }
} as BlogAutosaveHook;