// Desktop Window Management Hooks

const DesktopWindow = {
  mounted() {
    this.isDragging = false;
    this.dragOffset = { x: 0, y: 0 };
    
    const header = this.el.querySelector('.window-header');
    
    // Make window draggable
    header.addEventListener('mousedown', (e) => {
      if (e.target.closest('button')) return; // Don't drag if clicking buttons
      
      this.isDragging = true;
      const rect = this.el.getBoundingClientRect();
      this.dragOffset = {
        x: e.clientX - rect.left,
        y: e.clientY - rect.top
      };
      
      e.preventDefault();
    });
    
    document.addEventListener('mousemove', (e) => {
      if (!this.isDragging) return;
      
      const container = document.querySelector('.desktop-container');
      const containerRect = container.getBoundingClientRect();
      
      let newX = e.clientX - containerRect.left - this.dragOffset.x;
      let newY = e.clientY - containerRect.top - this.dragOffset.y;
      
      // Keep window within bounds
      newX = Math.max(0, Math.min(newX, containerRect.width - this.el.offsetWidth));
      newY = Math.max(0, Math.min(newY, containerRect.height - this.el.offsetHeight));
      
      this.el.style.left = newX + 'px';
      this.el.style.top = newY + 'px';
    });
    
    document.addEventListener('mouseup', () => {
      this.isDragging = false;
    });
  }
};

const ResizeHandle = {
  mounted() {
    this.isResizing = false;
    this.direction = this.el.dataset.direction;
    this.startSize = {};
    this.startPos = {};
    
    this.el.addEventListener('mousedown', (e) => {
      this.isResizing = true;
      this.window = this.el.closest('.desktop-window');
      
      const rect = this.window.getBoundingClientRect();
      this.startSize = {
        width: rect.width,
        height: rect.height
      };
      this.startPos = {
        x: rect.left,
        y: rect.top,
        mouseX: e.clientX,
        mouseY: e.clientY
      };
      
      e.preventDefault();
      e.stopPropagation();
    });
    
    document.addEventListener('mousemove', (e) => {
      if (!this.isResizing) return;
      
      const deltaX = e.clientX - this.startPos.mouseX;
      const deltaY = e.clientY - this.startPos.mouseY;
      
      let newWidth = this.startSize.width;
      let newHeight = this.startSize.height;
      let newLeft = this.startPos.x;
      let newTop = this.startPos.y;
      
      // Handle different resize directions
      if (this.direction.includes('e')) {
        newWidth = Math.max(300, this.startSize.width + deltaX);
      }
      if (this.direction.includes('w')) {
        newWidth = Math.max(300, this.startSize.width - deltaX);
        newLeft = this.startPos.x + deltaX;
      }
      if (this.direction.includes('s')) {
        newHeight = Math.max(200, this.startSize.height + deltaY);
      }
      if (this.direction.includes('n')) {
        newHeight = Math.max(200, this.startSize.height - deltaY);
        newTop = this.startPos.y + deltaY;
      }
      
      // Apply new dimensions and position
      this.window.style.width = newWidth + 'px';
      this.window.style.height = newHeight + 'px';
      this.window.style.left = (newLeft - this.startPos.x + parseInt(this.window.style.left)) + 'px';
      this.window.style.top = (newTop - this.startPos.y + parseInt(this.window.style.top)) + 'px';
    });
    
    document.addEventListener('mouseup', () => {
      this.isResizing = false;
    });
  }
};

// Export hooks for Phoenix LiveView
window.DesktopWindow = DesktopWindow;
window.ResizeHandle = ResizeHandle;