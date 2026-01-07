-- ============================================================================
-- CLIPS TABLE MIGRATION
-- Purpose: Add game-level clips for multi-angle video analysis
-- ============================================================================

-- Clips: Quick clips created during analysis (game-level, applies to all camera angles)
CREATE TABLE IF NOT EXISTS clips (
    clip_id TEXT PRIMARY KEY,
    game_id TEXT NOT NULL,

    -- Time boundaries (applies to ALL videos in the game)
    start_time_ms INTEGER NOT NULL,
    end_time_ms INTEGER NOT NULL,

    -- Metadata
    title TEXT NOT NULL,
    notes TEXT,
    tags TEXT, -- JSON array: ["Pick and Roll", "Defensive Breakdown"]

    -- Visual
    thumbnail_path TEXT, -- Path to multi-angle thumbnail grid

    -- Timestamps
    created_at INTEGER NOT NULL,
    modified_at INTEGER,

    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
);

-- Index for fast retrieval by game
CREATE INDEX IF NOT EXISTS idx_clips_game ON clips(game_id);
CREATE INDEX IF NOT EXISTS idx_clips_start_time ON clips(start_time_ms);
