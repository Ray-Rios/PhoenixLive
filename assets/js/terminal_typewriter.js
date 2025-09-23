// Terminal Typewriter Effect Hook
// Handles typing animation for terminal-style text

const TerminalTypewriter = {
  mounted() {
    this.typewriterSpeed = 80; // milliseconds per character
    this.blinkSpeed = 530; // cursor blink speed
    this.startDelay = 1000; // delay before typing starts
    
    // Get the text container
    this.container = this.el.querySelector('.typewriter-text');
    this.cursorContainer = this.el.querySelector('.typewriter-cursor');
    
    if (!this.container) {
      console.error('Typewriter container not found');
      return;
    }
    
    // Get the target text and clear the container
    this.targetText = this.container.dataset.text || "... it's a secret to Everybody.";
    this.container.textContent = '';
    
    // Start cursor blinking immediately
    this.startCursorBlink();
    
    // Start typing after delay
    setTimeout(() => {
      this.startTyping();
    }, this.startDelay);
  },
  
  startCursorBlink() {
    if (this.cursorContainer) {
      setInterval(() => {
        this.cursorContainer.style.opacity = 
          this.cursorContainer.style.opacity === '0' ? '1' : '0';
      }, this.blinkSpeed);
    }
  },
  
  startTyping() {
    let currentIndex = 0;
    
    const typeNextCharacter = () => {
      if (currentIndex < this.targetText.length) {
        this.container.textContent += this.targetText[currentIndex];
        currentIndex++;
        setTimeout(typeNextCharacter, this.typewriterSpeed);
      }
    };
    
    typeNextCharacter();
  },
  
  destroyed() {
    // Clean up any intervals if needed
  }
};

export { TerminalTypewriter };