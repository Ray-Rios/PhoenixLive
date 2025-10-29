// Color Picker Hook - sends color input changes to LiveView
export const ColorPicker = {
  mounted(this: any) {
    const input = this.el as HTMLInputElement;
    const eventName = input.dataset.event || 'update_color';
    
    console.log('✅ ColorPicker hook mounted for event:', eventName);
    
    // Listen for color changes
    input.addEventListener('input', (e) => {
      const color = (e.target as HTMLInputElement).value;
      console.log('🎨 ColorPicker: Color changed to', color, 'sending event:', eventName);
      
      // Push event to LiveView with the color value
      this.pushEvent(eventName, { color: color });
    });
  },
  
  destroyed() {
    console.log('🗑️ ColorPicker hook destroyed');
  }
};
