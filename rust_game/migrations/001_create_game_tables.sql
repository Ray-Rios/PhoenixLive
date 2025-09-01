-- Game sessions table
CREATE TABLE IF NOT EXISTS game_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    session_token TEXT NOT NULL UNIQUE,
    player_x FLOAT8 DEFAULT 0.0,
    player_y FLOAT8 DEFAULT 0.0,
    player_z FLOAT8 DEFAULT 0.0,
    rotation_x FLOAT8 DEFAULT 0.0,
    rotation_y FLOAT8 DEFAULT 0.0,
    rotation_z FLOAT8 DEFAULT 0.0,
    health INTEGER DEFAULT 100,
    score INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    experience INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    last_heartbeat TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Game events table for logging all game actions
CREATE TABLE IF NOT EXISTS game_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES game_sessions(id) ON DELETE CASCADE,
    player_id UUID,
    event_type TEXT NOT NULL,
    event_data JSONB,
    server_timestamp TIMESTAMPTZ DEFAULT NOW(),
    client_timestamp TIMESTAMPTZ,
    processed BOOLEAN DEFAULT false
);

-- Player stats table for persistent data
CREATE TABLE IF NOT EXISTS player_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    total_score INTEGER DEFAULT 0,
    total_playtime INTEGER DEFAULT 0,
    games_played INTEGER DEFAULT 0,
    highest_level INTEGER DEFAULT 1,
    achievements JSONB DEFAULT '{}',
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Game world state for persistent world elements
CREATE TABLE IF NOT EXISTS world_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    world_id TEXT NOT NULL,
    object_id TEXT NOT NULL,
    object_type TEXT NOT NULL,
    position JSONB NOT NULL,
    rotation JSONB DEFAULT '{"x": 0, "y": 0, "z": 0}',
    scale JSONB DEFAULT '{"x": 1, "y": 1, "z": 1}',
    properties JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(world_id, object_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_game_sessions_user_id ON game_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_game_sessions_active ON game_sessions(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_game_sessions_heartbeat ON game_sessions(last_heartbeat);

CREATE INDEX IF NOT EXISTS idx_game_events_session_id ON game_events(session_id);
CREATE INDEX IF NOT EXISTS idx_game_events_player_id ON game_events(player_id);
CREATE INDEX IF NOT EXISTS idx_game_events_type ON game_events(event_type);
CREATE INDEX IF NOT EXISTS idx_game_events_timestamp ON game_events(server_timestamp);
CREATE INDEX IF NOT EXISTS idx_game_events_unprocessed ON game_events(processed) WHERE processed = false;

CREATE INDEX IF NOT EXISTS idx_player_stats_user_id ON player_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_player_stats_score ON player_stats(total_score);

CREATE INDEX IF NOT EXISTS idx_world_state_world_id ON world_state(world_id);
CREATE INDEX IF NOT EXISTS idx_world_state_active ON world_state(is_active) WHERE is_active = true;