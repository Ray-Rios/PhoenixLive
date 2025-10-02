export const BlogAutosave = {
  mounted() {
    let form = this.el;
    let lastData = form.querySelector('[name="post[content]"]')?.value || '';
    let timer = setInterval(() => {
      let currentData = form.querySelector('[name="post[content]"]')?.value || '';
      if (currentData !== lastData && currentData.trim() !== '') {
        lastData = currentData;
        let formData = new FormData(form);
        let post = {};
        for (let [key, value] of formData.entries()) {
          if (key.startsWith('post[')) {
            post[key.slice(5, -1)] = value;
          }
        }
        this.pushEvent('autosave_draft', { post });
      }
    }, 10000);
    this.timer = timer;
  },
  destroyed() {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }
};