// Mock UE5 Game Streamer for Testing Pixel Streaming
const WebSocket = require('ws');

class MockGameStreamer {
    constructor() {
        this.ws = null;
        this.isConnected = false;
        this.connect();
    }
    
    connect() {
        console.log('🎮 Mock Game Streamer connecting to signaling server...');
        
        this.ws = new WebSocket('ws://localhost:9070');
        
        this.ws.on('open', () => {
            console.log('✅ Connected to signaling server');
            
            // Register as streamer
            this.ws.send(JSON.stringify({
                type: 'streamer'
            }));
            
            this.isConnected = true;
        });
        
        this.ws.on('message', (data) => {
            try {
                const message = JSON.parse(data);
                this.handleMessage(message);
            } catch (error) {
                console.error('Error parsing message:', error);
            }
        });
        
        this.ws.on('close', () => {
            console.log('❌ Disconnected from signaling server');
            this.isConnected = false;
            
            // Reconnect after 5 seconds
            setTimeout(() => this.connect(), 5000);
        });
        
        this.ws.on('error', (error) => {
            console.error('WebSocket error:', error);
        });
    }
    
    handleMessage(message) {
        console.log('📨 Received message:', message.type);
        
        switch (message.type) {
            case 'streamerConnected':
                console.log('🎯 Registered as streamer successfully');
                break;
                
            case 'offer':
                console.log('📞 Received WebRTC offer from viewer');
                // In a real game, this would set up WebRTC connection
                // For now, just acknowledge
                this.sendAnswer(message);
                break;
                
            case 'iceCandidate':
                console.log('🧊 Received ICE candidate');
                break;
                
            case 'gameInput':
                console.log('🎮 Received game input:', message.data && message.data.type);
                break;
        }
    }
    
    sendAnswer(offerMessage) {
        // Create a more realistic mock WebRTC answer
        const mockSdp = `v=0
o=- 123456789 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0 1
a=msid-semantic: WMS mock-stream
m=video 9 UDP/TLS/RTP/SAVPF 96
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:mock
a=ice-pwd:mockpassword
a=fingerprint:sha-256 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00
a=setup:active
a=mid:0
a=sendonly
a=rtcp-mux
a=rtpmap:96 H264/90000
a=ssrc:1234567890 cname:mock-video
a=ssrc:1234567890 msid:mock-stream mock-video-track
m=audio 9 UDP/TLS/RTP/SAVPF 111
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:mock
a=ice-pwd:mockpassword
a=fingerprint:sha-256 00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00
a=setup:active
a=mid:1
a=sendonly
a=rtcp-mux
a=rtpmap:111 opus/48000/2
a=ssrc:1234567891 cname:mock-audio
a=ssrc:1234567891 msid:mock-stream mock-audio-track`;

        const mockAnswer = {
            type: 'answer',
            answer: {
                type: 'answer',
                sdp: mockSdp
            },
            target: 'viewer'
        };
        
        console.log('📤 Sending realistic mock WebRTC answer');
        this.ws.send(JSON.stringify(mockAnswer));
        
        // Send some mock ICE candidates after a delay
        setTimeout(() => {
            this.sendMockIceCandidates();
        }, 1000);
    }
    
    sendMockIceCandidates() {
        const mockCandidates = [
            'candidate:1 1 UDP 2130706431 127.0.0.1 54400 typ host',
            'candidate:2 1 UDP 1694498815 192.168.1.100 54401 typ srflx raddr 127.0.0.1 rport 54400',
        ];
        
        mockCandidates.forEach((candidate, index) => {
            setTimeout(() => {
                const iceMessage = {
                    type: 'iceCandidate',
                    candidate: {
                        candidate: candidate,
                        sdpMLineIndex: 0,
                        sdpMid: '0'
                    },
                    target: 'viewer'
                };
                
                console.log('🧊 Sending mock ICE candidate:', index + 1);
                this.ws.send(JSON.stringify(iceMessage));
            }, index * 500);
        });
    }
}

console.log('🚀 Starting Mock Game Streamer...');
console.log('📝 This simulates a UE5 game connecting to pixel streaming');
console.log('🔗 Connect your browser to http://localhost:9070 to test');
console.log('⚠️  NOTE: This is a MOCK - no actual video will stream');
console.log('🎮 For real video, you need a packaged UE5 game with Pixel Streaming');

new MockGameStreamer();