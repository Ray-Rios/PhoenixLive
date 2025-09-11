// File Drag & Drop Hook for Phoenix LiveView
export const FileDragDrop = {
  mounted() {
    const dropZone = this.el.querySelector('#drop-zone');
    const fileInput = this.el.querySelector('#file-upload');
    
    // Prevent default drag behaviors
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      dropZone.addEventListener(eventName, preventDefaults, false);
      document.body.addEventListener(eventName, preventDefaults, false);
    });

    // Highlight drop zone when item is dragged over it
    ['dragenter', 'dragover'].forEach(eventName => {
      dropZone.addEventListener(eventName, highlight, false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
      dropZone.addEventListener(eventName, unhighlight, false);
    });

    // Handle dropped files
    dropZone.addEventListener('drop', handleDrop, false);
    
    // Handle file input change
    fileInput.addEventListener('change', handleFileSelect, false);

    function preventDefaults(e) {
      e.preventDefault();
      e.stopPropagation();
    }

    function highlight(e) {
      dropZone.classList.add('border-blue-500', 'bg-blue-900/20');
    }

    function unhighlight(e) {
      dropZone.classList.remove('border-blue-500', 'bg-blue-900/20');
    }

    function handleDrop(e) {
      const dt = e.dataTransfer;
      const files = dt.files;
      handleFiles(files);
    }

    function handleFileSelect(e) {
      const files = e.target.files;
      handleFiles(files);
    }

    function handleFiles(files) {
      const fileArray = Array.from(files);
      
      // Validate files
      const validFiles = fileArray.filter(file => {
        // Check file size (50MB limit)
        if (file.size > 50 * 1024 * 1024) {
          alert(`File "${file.name}" is too large. Maximum size is 50MB.`);
          return false;
        }
        
        // Check file type
        const allowedTypes = [
          'image/jpeg', 'image/png', 'image/gif', 'image/webp',
          'video/mp4', 'video/avi', 'video/mov', 'video/wmv',
          'audio/mp3', 'audio/wav', 'audio/ogg',
          'application/pdf', 'application/msword',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'text/plain', 'text/csv',
          'application/zip', 'application/x-rar-compressed'
        ];
        
        if (!allowedTypes.includes(file.type)) {
          alert(`File type "${file.type}" is not supported for file "${file.name}".`);
          return false;
        }
        
        return true;
      });

      if (validFiles.length === 0) return;

      // Show upload progress
      showUploadProgress(validFiles);

      // Process files
      validFiles.forEach((file, index) => {
        const reader = new FileReader();
        
        reader.onload = (e) => {
          const fileData = {
            name: file.name,
            type: file.type,
            size: file.size,
            data: e.target.result,
            lastModified: file.lastModified
          };
          
          // Send to LiveView
          this.pushEvent("file_drop", { files: [fileData] });
        };
        
        reader.readAsDataURL(file);
      });
    }

    function showUploadProgress(files) {
      // Create progress indicator
      const progressDiv = document.createElement('div');
      progressDiv.className = 'fixed top-4 right-4 bg-gray-800 text-white p-4 rounded-lg shadow-lg z-50';
      progressDiv.innerHTML = `
        <div class="flex items-center space-x-2">
          <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-500"></div>
          <span>Uploading ${files.length} file(s)...</span>
        </div>
      `;
      
      document.body.appendChild(progressDiv);
      
      // Remove after 3 seconds
      setTimeout(() => {
        if (progressDiv.parentNode) {
          progressDiv.parentNode.removeChild(progressDiv);
        }
      }, 3000);
    }
  }
};

// File Upload Hook for traditional file input
export const FileUpload = {
  mounted() {
    this.el.addEventListener('change', (e) => {
      const files = Array.from(e.target.files);
      
      files.forEach(file => {
        const reader = new FileReader();
        
        reader.onload = (event) => {
          const fileData = {
            name: file.name,
            type: file.type,
            size: file.size,
            data: event.target.result,
            lastModified: file.lastModified
          };
          
          this.pushEvent("file_selected", fileData);
        };
        
        reader.readAsDataURL(file);
      });
      
      // Clear the input
      e.target.value = '';
    });
  }
};