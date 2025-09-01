-- Game sessions table for MMO player data
CREATE TABLE IF NOT EXISTS game_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    session_token VARCHAR(255) NOT NULL,
    player_x FLOAT DEFAULT 0.0,
    player_y FLOAT DEFAULT 0.0,
    player_z FLOAT DEFAULT 0.0,
    rotation_x FLOAT DEFAULT 0.0,
    rotation_y FLOAT DEFAULT 0.0,
    rotation_z FLOAT DEFAULT 0.0,
    health INTEGER DEFAULT 100,
    score INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1,
    experience INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Game events table for MMO event logging
CREATE TABLE IF NOT EXISTS game_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES game_sessions(id),
    event_type VARCHAR(50) NOT NULL,
    event_data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Player stats table for MMO character progression
CREATE TABLE IF NOT EXISTS player_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    character_name VARCHAR(100),
    character_class VARCHAR(50),
    strength INTEGER DEFAULT 10,
    dexterity INTEGER DEFAULT 10,
    intelligence INTEGER DEFAULT 10,
    vitality INTEGER DEFAULT 10,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- World state table for MMO persistent world data
CREATE TABLE IF NOT EXISTS world_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zone_name VARCHAR(100) NOT NULL,
    state_data JSONB,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);