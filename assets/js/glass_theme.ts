export const GlassTheme = {
  mounted(this: any) {
    console.log('✅ GlassTheme hook mounted');
    
    // Listen for glass theme updates from LiveView
    this.handleEvent("update_glass_theme", (data: any) => {
      console.log('🎨 GlassTheme: Received update_glass_theme from LiveView:', data);
      this.applyGlassTheme(data);
      
      // If this is a global update, dispatch a window event for all components
      if (data.global) {
        window.dispatchEvent(new CustomEvent('glass-theme-update', { detail: data }));
        console.log('📢 GlassTheme: Dispatched glass-theme-update window event');
      }
    });
    
    // Listen for global glass theme updates from other components
    window.addEventListener('glass-theme-update', (event: any) => {
      console.log('👂 GlassTheme: Received glass-theme-update window event:', event.detail);
      this.applyGlassTheme(event.detail);
    });
    
    console.log('👂 GlassTheme: Now listening for update_glass_theme and glass-theme-update events');
  },

  applyGlassTheme(data: any) {
    console.log('🎨 Applying glass theme:', data);
    const root = document.documentElement;
    
    // Convert theme to CSS values - base colors with placeholder for opacity
    const themeColors = {
      'dark': { bg: 'rgba(17, 24, 39, OPACITY)', border: 'rgba(255, 255, 255, 0.15)' },
      'blue': { bg: 'rgba(59, 130, 246, OPACITY)', border: 'rgba(59, 130, 246, 0.3)' },
      'purple': { bg: 'rgba(147, 51, 234, OPACITY)', border: 'rgba(147, 51, 234, 0.3)' },
      'green': { bg: 'rgba(34, 197, 94, OPACITY)', border: 'rgba(34, 197, 94, 0.3)' },
      'red': { bg: 'rgba(239, 68, 68, OPACITY)', border: 'rgba(239, 68, 68, 0.3)' },
      'amber': { bg: 'rgba(245, 158, 11, OPACITY)', border: 'rgba(245, 158, 11, 0.3)' },
      'teal': { bg: 'rgba(20, 184, 166, OPACITY)', border: 'rgba(20, 184, 166, 0.3)' },
    };

    let bgColor, borderColor;
    const opacity = data.opacity || 0.15;
    const blur = data.blur || 15;

    // Check if custom color is provided
    if (data.custom_color && data.custom_color !== '') {
      // Convert hex to rgba with custom opacity
      const hex = data.custom_color.replace('#', '');
      const r = parseInt(hex.substr(0, 2), 16);
      const g = parseInt(hex.substr(2, 2), 16);
      const b = parseInt(hex.substr(4, 2), 16);
      
      bgColor = `rgba(${r}, ${g}, ${b}, ${opacity})`;
      borderColor = `rgba(${r}, ${g}, ${b}, ${Math.min(1, parseFloat(opacity.toString()) + 0.2)})`;
    } else {
      // Use predefined theme colors with dynamic opacity
      const theme = themeColors[data.theme as keyof typeof themeColors] || themeColors.dark;
      bgColor = theme.bg.replace('OPACITY', opacity.toString());
      borderColor = theme.border;
    }

    // Update CSS custom properties globally
    root.style.setProperty('--glass-bg', bgColor);
    root.style.setProperty('--glass-border', borderColor);
    root.style.setProperty('--glass-blur', `${blur}px`);
    root.style.setProperty('--glass-saturation', '120%');

    console.log('Glass theme applied globally:', {
      bg: root.style.getPropertyValue('--glass-bg'),
      border: root.style.getPropertyValue('--glass-border'),
      blur: root.style.getPropertyValue('--glass-blur'),
      custom_color: data.custom_color
    });
  }
};