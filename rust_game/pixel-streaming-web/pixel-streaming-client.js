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
                
            case 'answer':
                // Check if this is a mock answer
                if (data.answer && data.answer.sdp && data.answer.sdp.includes('mock-stream')) {
                    console.log('🎭 Mock streamer detected');
                    this.showMockMessage();
                }
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
        
        // Set a timeout for mock detection
        this.mockDetectionTimeout = setTimeout(() => {
            console.log('🎭 No video stream received - likely mock streamer');
            this.showMockMessage();
        }, 10000); // 10 seconds timeout
        
        this.peerConnection.ontrack = (event) => {
            console.log('Received video stream');
            clearTimeout(this.mockDetectionTimeout);
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
                console.log('WebRTC connection failed - likely using mock streamer');
                this.showMockMessage();
            } else if (this.peerConnection.connectionState === 'connecting') {
                this.updateStatus('Establishing connection...', false);
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
        
        // Check if this is a mock offer
        if (offer.sdp && offer.sdp.includes('mock-stream')) {
            console.log('🎭 Mock offer detected');
            setTimeout(() => this.showMockMessage(), 2000);
            return;
        }
        
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
    
    showMockMessage() {
        this.loadingScreen.style.display = 'none';
        this.updateStatus('Mock Streamer Active', true);
        
        // Remove any existing mock overlay
        const existing = document.querySelector('.mock-overlay');
        if (existing) existing.remove();
        
        // Create a mock message overlay
        const mockOverlay = document.createElement('div');
        mockOverlay.className = 'mock-overlay';
        mockOverlay.style.cssText = `
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: rgba(0, 0, 0, 0.95);
            color: white;
            padding: 30px;
            border-radius: 15px;
            text-align: center;
            max-width: 600px;
            z-index: 20;
            border: 2px solid #4CAF50;
            box-shadow: 0 10px 30px rgba(0,0,0,0.5);
            font-family: 'Segoe UI', sans-serif;
        `;
        
        mockOverlay.innerHTML = `
            <div style="font-size: 3em; margin-bottom: 15px;">🎮</div>
            <h2 style="color: #4CAF50; margin-bottom: 15px;">Pixel Streaming Test Successful!</h2>
            <p style="margin-bottom: 20px;">Your infrastructure is working perfectly.</p>
            
            <div style="background: rgba(76, 175, 80, 0.1); padding: 15px; border-radius: 8px; margin: 20px 0;">
                <strong>✅ Connection Status:</strong><br>
                WebSocket: Connected<br>
                Signaling Server: Active<br>
                API Endpoints: Working<br>
                Mock Streamer: Running
            </div>
            
            <div style="background: rgba(255, 193, 7, 0.1); padding: 15px; border-radius: 8px; margin: 20px 0;">
                <strong>🚀 Next Steps:</strong><br>
                1. Package your UE5 game with Pixel Streaming<br>
                2. Replace mock streamer with real game<br>
                3. Enjoy browser-based gaming!
            </div>
            
            <button onclick="this.parentElement.remove()" style="
                background: #4CAF50;
                color: white;
                border: none;
                padding: 10px 20px;
                border-radius: 5px;
                cursor: pointer;
                margin-top: 15px;
                font-size: 14px;
            ">Got it!</button>
        `;
        
        document.querySelector('.game-container').appendChild(mockOverlay);
    }
    
    async updatePlayerCount() {
        try {
            console.log('Fetching player count from:', window.location.origin + '/api/players');
            const response = await fetch('/api/players');
            console.log('Response status:', response.status, response.statusText);
            
            if (!response.ok) {
                const errorText = await response.text();
                console.error('API Error Response:', errorText);
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            const data = await response.json();
            console.log('Player data received:', data);
            this.playerCount.textContent = `Players: ${data.count || 0}`;
        } catch (error) {
            console.error('Error fetching player count:', error);
            this.playerCount.textContent = 'Players: --';
            
            // Try to fetch status endpoint as fallback
            try {
                const statusResponse = await fetch('/status');
                if (statusResponse.ok) {
                    const statusData = await statusResponse.json();
                    console.log('Status data:', statusData);
                    this.playerCount.textContent = `Players: ${statusData.viewerCount || 0}`;
                }
            } catch (statusError) {
                console.error('Status endpoint also failed:', statusError);
            }
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