// Pixel Streaming Signaling Server
const WebSocket = require('ws');
const http = require('http');
const fs = require('fs');
const path = require('path');

// Create HTTP server for web interface
const server = http.createServer((req, res) => {
    console.log(`HTTP ${req.method} ${req.url}`);

    // Handle CORS preflight requests
    if (req.method === 'OPTIONS') {
        res.writeHead(200, {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type'
        });
        res.end();
        return;
    }

    // Handle status endpoint
    if (req.url === '/status') {
        const status = {
            streamerConnected: !!streamerSocket,
            viewerCount: viewers.size,
            timestamp: new Date().toISOString(),
            gameStatus: streamerSocket ? 'running' : 'waiting',
            message: streamerSocket ? 'Game server is running and ready for connections' : 'Waiting for game server to connect'
        };

        res.writeHead(200, {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type'
        });
        res.end(JSON.stringify(status, null, 2));
        return;
    }

    // Handle players endpoint
    if (req.url === '/api/players') {
        console.log('API request for players endpoint');
        const playerData = {
            count: viewers.size,
            connected: !!streamerSocket,
            timestamp: new Date().toISOString()
        };

        res.writeHead(200, {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type'
        });
        res.end(JSON.stringify(playerData));
        return;
    }

    let filePath = path.join(__dirname, 'web', req.url === '/' ? 'index.html' : req.url);

    // Security check
    if (!filePath.startsWith(path.join(__dirname, 'web'))) {
        res.writeHead(403);
        res.end('Forbidden');
        return;
    }

    fs.readFile(filePath, (err, data) => {
        if (err) {
            res.writeHead(404);
            res.end('Not Found');
            return;
        }

        const ext = path.extname(filePath);
        const contentType = {
            '.html': 'text/html',
            '.js': 'application/javascript',
            '.css': 'text/css',
            '.json': 'application/json'
        }[ext] || 'text/plain';

        res.writeHead(200, { 'Content-Type': contentType });
        res.end(data);
    });
});

// WebSocket server for signaling
const wss = new WebSocket.Server({ server });

let streamerSocket = null;
const viewers = new Set();

wss.on('connection', (ws, req) => {
    console.log('New connection from:', req.connection.remoteAddress);

    ws.on('message', (message) => {
        try {
            const data = JSON.parse(message);

            // Handle different message types
            switch (data.type) {
                case 'streamer':
                    streamerSocket = ws;
                    console.log('Streamer connected');
                    ws.send(JSON.stringify({ type: 'streamerConnected' }));
                    break;

                case 'viewer':
                    viewers.add(ws);
                    console.log('Viewer connected, total viewers:', viewers.size);

                    // If streamer is available, start connection
                    if (streamerSocket) {
                        ws.send(JSON.stringify({ type: 'streamerAvailable' }));
                    }
                    break;

                case 'offer':
                case 'answer':
                case 'iceCandidate':
                    // Forward WebRTC signaling between streamer and viewer
                    if (data.target === 'streamer' && streamerSocket) {
                        streamerSocket.send(message);
                    } else if (data.target === 'viewer') {
                        // Forward to specific viewer (simplified - in production, track viewer IDs)
                        viewers.forEach(viewer => {
                            if (viewer !== ws) {
                                viewer.send(message);
                            }
                        });
                    }
                    break;

                case 'gameInput':
                    // Forward game input to UE5 streamer
                    if (streamerSocket) {
                        streamerSocket.send(message);
                    }
                    break;
            }
        } catch (error) {
            console.error('Error parsing message:', error);
        }
    });

    ws.on('close', () => {
        if (ws === streamerSocket) {
            streamerSocket = null;
            console.log('Streamer disconnected');

            // Notify all viewers
            viewers.forEach(viewer => {
                viewer.send(JSON.stringify({ type: 'streamerDisconnected' }));
            });
        } else {
            viewers.delete(ws);
            console.log('Viewer disconnected, remaining viewers:', viewers.size);
        }
    });
});

const PORT = process.env.PIXEL_STREAMING_PORT || 9070;
server.listen(PORT, () => {
    console.log(`🎮 Pixel Streaming Server running on port ${PORT}`);
    console.log(`🌐 Web interface: http://localhost:${PORT}`);
    console.log(`🔌 WebSocket signaling ready`);
});