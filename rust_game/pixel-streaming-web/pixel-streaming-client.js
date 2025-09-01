// Pixel Streaming Client for UE5 Game
class PixelStreamingClient {
    constructor() {
        this.ws = null;
        this.peerConnection = null;
        this.gameVideo = document.getElementById('gameVideo');
        this.loadingScreen = document.getElementById('loadingScreen');
        this.errorScreen = document.getElementById('errorScreen');
        this.statusIndicator = document.getElementById('statusIndicator');
        this.statusText = document.getElementById('statusText');
        this.playerCount = document.getElementById('playerCount');
        
        this.isConnected = false;
        this.isAudioEnabled = true;
        
        this.init();
    }
    
    init() {
        this.setupWebSocket();
        this.setupInputHandlers();
        this.updatePlayerCount();
    }
    
    setupWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}`;
        
        this.ws = new WebSocket(wsUrl);
        
        this.ws.onopen = () => {
            console.log('WebSocket connected');
            this.updateStatus('Connecting to game...', false);
            
            // Register as viewer
            this.ws.send(JSON.stringify({
                type: 'viewer'
            }));
        };
        
        this.ws.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                this.handleSignalingMessage(data);
            } catch (error) {
                console.error('Error parsing WebSocket message:', error);
            }
        };
        
        this.ws.onclose = () => {
            console.log('WebSocket disconnected');
            this.updateStatus('Disconnected', false);
            this.showError();
        };
        
        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
            this.showError();
        };
    }
    
    handleSignalingMessage(data) {
        switch (data.type) {
            case 'streamerAvailable':
                this.updateStatus('Game server ready', false);
                this.setupPeerConnection();
                break;
                
            case 'streamerDisconnected':
                this.updateStatus('Game server offline', false);
                this.showError();
                break;
                
            case 'offer':
                this.handleOffer(data.offer);
                break;
                
            case 'iceCandidate':
                this.handleIceCandidate(data.candidate);
                break;
        }
    }
    
    setupPeerConnection() {
        this.peerConnection = new RTCPeerConnection({
            iceServers: [
                { urls: 'stun:stun.l.google.com:19302' }
            ]
        });
        
        this.peerConnection.ontrack = (event) => {
            console.log('Received video stream');
            this.gameVideo.srcObject = event.streams[0];
            this.hideLoading();
            this.updateStatus('Connected', true);
        };
        
        this.peerConnection.onicecandidate = (event) => {
            if (event.candidate) {
                this.ws.send(JSON.stringify({
                    type: 'iceCandidate',
                    candidate: event.candidate,
                    target: 'streamer'
                }));
            }
        };
        
        this.peerConnection.onconnectionstatechange = () => {
            console.log('Connection state:', this.peerConnection.connectionState);
            
            if (this.peerConnection.connectionState === 'connected') {
                this.isConnected = true;
                this.updateStatus('Playing', true);
            } else if (this.peerConnection.connectionState === 'failed') {
                this.showError();
            }
        };
        
        // Create data channel for game input
        this.dataChannel = this.peerConnection.createDataChannel('input', {
            ordered: true
        });
        
        this.dataChannel.onopen = () => {
            console.log('Data channel opened');
        };
    }
    
    async handleOffer(offer) {
        if (!this.peerConnection) return;
        
        await this.peerConnection.setRemoteDescription(offer);
        const answer = await this.peerConnection.createAnswer();
        await this.peerConnection.setLocalDescription(answer);
        
        this.ws.send(JSON.stringify({
            type: 'answer',
            answer: answer,
            target: 'streamer'
        }));
    }
    
    async handleIceCandidate(candidate) {
        if (!this.peerConnection) return;
        
        await this.peerConnection.addIceCandidate(candidate);
    }
    
    setupInputHandlers() {
        // Mouse events
        this.gameVideo.addEventListener('click', (e) => {
            this.sendInput('mouseClick', {
                x: e.offsetX / this.gameVideo.offsetWidth,
                y: e.offsetY / this.gameVideo.offsetHeight,
                button: e.button
            });
        });
        
        this.gameVideo.addEventListener('mousemove', (e) => {
            this.sendInput('mouseMove', {
                x: e.offsetX / this.gameVideo.offsetWidth,
                y: e.offsetY / this.gameVideo.offsetHeight
            });
        });
        
        // Keyboard events
        document.addEventListener('keydown', (e) => {
            if (this.isConnected) {
                e.preventDefault();
                this.sendInput('keyDown', {
                    key: e.code,
                    keyCode: e.keyCode
                });
            }
        });
        
        document.addEventListener('keyup', (e) => {
            if (this.isConnected) {
                e.preventDefault();
                this.sendInput('keyUp', {
                    key: e.code,
                    keyCode: e.keyCode
                });
            }
        });
        
        // Touch events for mobile
        this.gameVideo.addEventListener('touchstart', (e) => {
            e.preventDefault();
            const touch = e.touches[0];
            const rect = this.gameVideo.getBoundingClientRect();
            this.sendInput('touchStart', {
                x: (touch.clientX - rect.left) / rect.width,
                y: (touch.clientY - rect.top) / rect.height
            });
        });
        
        this.gameVideo.addEventListener('touchmove', (e) => {
            e.preventDefault();
            const touch = e.touches[0];
            const rect = this.gameVideo.getBoundingClientRect();
            this.sendInput('touchMove', {
                x: (touch.clientX - rect.left) / rect.width,
                y: (touch.clientY - rect.top) / rect.height
            });
        });
        
        this.gameVideo.addEventListener('touchend', (e) => {
            e.preventDefault();
            this.sendInput('touchEnd', {});
        });
    }
    
    sendInput(type, data) {
        if (this.dataChannel && this.dataChannel.readyState === 'open') {
            this.dataChannel.send(JSON.stringify({
                type: type,
                data: data,
                timestamp: Date.now()
            }));
        }
    }
    
    updateStatus(text, connected) {
        this.statusText.textContent = text;
        this.statusIndicator.classList.toggle('connected', connected);
    }
    
    hideLoading() {
        this.loadingScreen.style.display = 'none';
    }
    
    showError() {
        this.loadingScreen.style.display = 'none';
        this.errorScreen.style.display = 'flex';
    }
    
    async updatePlayerCount() {
        try {
            const response = await fetch('/api/players');
            const data = await response.json();
            this.playerCount.textContent = `Players: ${data.count || 0}`;
        } catch (error) {
            console.error('Error fetching player count:', error);
        }
        
        // Update every 30 seconds
        setTimeout(() => this.updatePlayerCount(), 30000);
    }
}

// Control functions
function toggleFullscreen() {
    if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen();
    } else {
        document.exitFullscreen();
    }
}

function toggleAudio() {
    const video = document.getElementById('gameVideo');
    video.muted = !video.muted;
    
    const btn = event.target;
    btn.textContent = video.muted ? '🔇 Audio' : '🔊 Audio';
}

function showStats() {
    // TODO: Implement stats overlay
    alert('Stats feature coming soon!');
}

function reconnect() {
    location.reload();
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
    new PixelStreamingClient();
});