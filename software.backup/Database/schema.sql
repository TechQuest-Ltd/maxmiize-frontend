-- ============================================================================
-- MAXMIIZE SPORTS ANALYSIS PLATFORM - DATABASE SCHEMA
-- Version: 1.0
-- Platform: SQLite 3
-- Purpose: Production database schema for basketball video analysis
-- ============================================================================

-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- ============================================================================
-- CORE PROJECT & ORGANIZATION TABLES
-- ============================================================================

-- Projects: Season-level organization (e.g., "2024-25 Season")
CREATE TABLE IF NOT EXISTS projects (
    project_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    season TEXT,
    sport TEXT DEFAULT 'basketball',
    created_at INTEGER NOT NULL, -- Unix timestamp in milliseconds
    modified_at INTEGER NOT NULL,
    settings TEXT, -- JSON: user preferences, defaults, team info
    UNIQUE(name, season)
);

-- Teams: Own team and opponents
CREATE TABLE IF NOT EXISTS teams (
    team_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    name TEXT NOT NULL,
    is_opponent INTEGER NOT NULL DEFAULT 0, -- 0 = own team, 1 = opponent
    conference TEXT,
    division TEXT,
    season_year TEXT,
    primary_color TEXT,
    secondary_color TEXT,
    logo_path TEXT,
    notes TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE,
    UNIQUE(project_id, name, season_year)
);

-- Players: Team rosters (own team and opponents)
CREATE TABLE IF NOT EXISTS players (
    player_id TEXT PRIMARY KEY,
    team_id TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    jersey_number INTEGER NOT NULL,
    position TEXT, -- PG, SG, SF, PF, C
    height_inches INTEGER,
    weight_lbs INTEGER,
    class_year TEXT, -- Freshman, Sophomore, Junior, Senior, Graduate
    birth_date TEXT,
    notes TEXT,
    is_active INTEGER DEFAULT 1, -- For tracking injuries or availability
    created_at INTEGER NOT NULL,
    FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE,
    UNIQUE(team_id, jersey_number)
);

-- ============================================================================
-- GAME & VIDEO MANAGEMENT TABLES
-- ============================================================================

-- Games: Individual games within a season
CREATE TABLE IF NOT EXISTS games (
    game_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    opponent_team_id TEXT,
    game_date INTEGER NOT NULL, -- Unix timestamp
    game_time TEXT, -- HH:MM format
    location TEXT, -- Venue name
    is_home_game INTEGER NOT NULL DEFAULT 1, -- 1 = home, 0 = away
    final_score_us INTEGER,
    final_score_opponent INTEGER,
    overtime_periods INTEGER DEFAULT 0,
    game_type TEXT, -- regular_season, playoff, exhibition, practice
    game_notes TEXT,
    weather_conditions TEXT, -- For outdoor sports, NULL for basketball
    attendance INTEGER,
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE,
    FOREIGN KEY (opponent_team_id) REFERENCES teams(team_id) ON DELETE SET NULL
);

-- Videos: Video files associated with games
CREATE TABLE IF NOT EXISTS videos (
    video_id TEXT PRIMARY KEY,
    game_id TEXT NOT NULL,
    file_path TEXT NOT NULL, -- Relative path within project bundle
    file_size_bytes INTEGER,
    camera_angle TEXT NOT NULL, -- baseline, sideline, elevated, broadcast, bench
    duration_ms INTEGER NOT NULL, -- Duration in milliseconds
    frame_rate REAL NOT NULL, -- e.g., 29.97, 30, 60
    resolution_width INTEGER NOT NULL,
    resolution_height INTEGER NOT NULL,
    codec TEXT NOT NULL, -- h264, h265, prores, mpeg4
    bitrate_kbps INTEGER,
    is_primary INTEGER DEFAULT 0, -- Primary angle for the game
    timecode_offset_ms INTEGER DEFAULT 0, -- For multi-angle synchronization
    import_date INTEGER NOT NULL,
    thumbnail_path TEXT, -- Path to generated thumbnail
    metadata TEXT, -- JSON: additional codec info, camera settings
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
);

-- Video Angles Sync: Track synchronization relationships between video angles
CREATE TABLE IF NOT EXISTS video_sync (
    sync_id TEXT PRIMARY KEY,
    game_id TEXT NOT NULL,
    primary_video_id TEXT NOT NULL,
    secondary_video_id TEXT NOT NULL,
    offset_ms INTEGER NOT NULL, -- Time offset of secondary relative to primary
    sync_quality TEXT DEFAULT 'manual', -- manual, auto, timecode
    sync_confidence REAL, -- 0.0 to 1.0 for auto-sync
    created_at INTEGER NOT NULL,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE,
    FOREIGN KEY (primary_video_id) REFERENCES videos(video_id) ON DELETE CASCADE,
    FOREIGN KEY (secondary_video_id) REFERENCES videos(video_id) ON DELETE CASCADE,
    UNIQUE(primary_video_id, secondary_video_id)
);

-- Clips: Multi-angle video clips for game moments
CREATE TABLE IF NOT EXISTS clips (
    clip_id TEXT PRIMARY KEY,
    game_id TEXT NOT NULL,
    start_time_ms INTEGER NOT NULL,
    end_time_ms INTEGER NOT NULL,
    title TEXT NOT NULL,
    notes TEXT,
    tags TEXT, -- JSON array of tags
    thumbnail_path TEXT,
    created_at INTEGER NOT NULL,
    modified_at INTEGER,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
);

-- ============================================================================
-- TAGGING & EVENT TRACKING TABLES
-- ============================================================================

-- Tagging Templates: Reusable tagging configurations
CREATE TABLE IF NOT EXISTS tagging_templates (
    template_id TEXT PRIMARY KEY,
    project_id TEXT, -- NULL = global template
    name TEXT NOT NULL,
    description TEXT,
    sport TEXT DEFAULT 'basketball',
    template_data TEXT NOT NULL, -- JSON: complete template structure with categories, hotkeys
    is_default INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE
);

-- Tags: Basketball events tagged during analysis
CREATE TABLE IF NOT EXISTS tags (
    tag_id TEXT PRIMARY KEY,
    video_id TEXT NOT NULL,
    game_id TEXT NOT NULL, -- Denormalized for fast filtering
    possession_id TEXT, -- Link to possession (fundamental organizational unit)
    timestamp_ms INTEGER NOT NULL, -- Timestamp in video
    game_clock TEXT, -- Game clock at time of event (e.g., "10:45" in Q2)
    period INTEGER, -- 1, 2, 3, 4 for quarters, 5+ for overtime
    period_type TEXT, -- quarter, half, overtime
    
    -- Event classification
    event_category TEXT NOT NULL, -- offense, defense, transition, special_teams
    event_type TEXT NOT NULL, -- shot, turnover, rebound, assist, steal, block, foul
    event_subtype TEXT, -- three_point_shot, bad_pass, offensive_rebound, etc.
    outcome TEXT, -- made, missed, successful, unsuccessful
    
    -- Player association
    player_id TEXT, -- Primary player involved
    secondary_player_id TEXT, -- Assist player, player fouled, etc.
    team_id TEXT, -- Which team (for opponent analysis)
    
    -- Basketball-specific metadata (stored as JSON for flexibility)
    shot_location_x REAL, -- Court X coordinate (normalized 0-1)
    shot_location_y REAL, -- Court Y coordinate (normalized 0-1)
    shot_distance_feet REAL,
    shot_zone TEXT, -- paint, mid_range, three_point_corner, three_point_wing, three_point_top
    
    offensive_set TEXT, -- pick_and_roll, motion, horns, princeton, iso, post_up
    defensive_scheme TEXT, -- man_to_man, zone_2_3, zone_3_2, zone_1_3_1, press_full, press_half
    
    is_transition INTEGER DEFAULT 0, -- 1 if transition play
    is_fast_break INTEGER DEFAULT 0,
    possession_number INTEGER, -- Track possession count in game
    
    -- Additional context
    points_scored INTEGER DEFAULT 0,
    foul_type TEXT, -- shooting, offensive, technical, flagrant
    notes TEXT,
    custom_metadata TEXT, -- JSON: additional custom fields
    
    -- Tracking
    tagged_by TEXT, -- User who created the tag
    created_at INTEGER NOT NULL,
    modified_at INTEGER,
    
    FOREIGN KEY (video_id) REFERENCES videos(video_id) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE,
    FOREIGN KEY (possession_id) REFERENCES possessions(possession_id) ON DELETE SET NULL,
    FOREIGN KEY (player_id) REFERENCES players(player_id) ON DELETE SET NULL,
    FOREIGN KEY (secondary_player_id) REFERENCES players(player_id) ON DELETE SET NULL,
    FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE SET NULL
);

-- Possessions: Basketball possessions (fundamental organizational unit per SRS)
CREATE TABLE IF NOT EXISTS possessions (
    possession_id TEXT PRIMARY KEY,
    game_id TEXT NOT NULL,
    team_type TEXT NOT NULL, -- offense, defense
    start_time_ms INTEGER NOT NULL,
    end_time_ms INTEGER, -- NULL if possession still active
    period INTEGER NOT NULL, -- 1, 2, 3, 4 for quarters, 5+ for overtime

    -- Possession tracking
    start_trigger TEXT NOT NULL, -- game_start, made_basket, defensive_rebound, steal, turnover_gained, jump_ball
    end_trigger TEXT, -- field_goal_made, offensive_rebound, turnover_lost, foul, quarter_end
    outcome TEXT, -- score, turnover, defensive_rebound, foul, end_of_period
    points_scored INTEGER DEFAULT 0,

    -- Metadata
    tag_count INTEGER DEFAULT 0, -- Number of tags in this possession
    duration_ms INTEGER, -- Calculated: end_time_ms - start_time_ms
    notes TEXT,
    created_at INTEGER NOT NULL,
    modified_at INTEGER,

    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
);

-- Tag Links: Connect related tags (e.g., shot + assist, shot + rebound)
CREATE TABLE IF NOT EXISTS tag_links (
    link_id TEXT PRIMARY KEY,
    parent_tag_id TEXT NOT NULL,
    child_tag_id TEXT NOT NULL,
    relationship_type TEXT NOT NULL, -- assist, rebound_after_miss, foul_on_shot, turnover_led_to_score
    created_at INTEGER NOT NULL,
    FOREIGN KEY (parent_tag_id) REFERENCES tags(tag_id) ON DELETE CASCADE,
    FOREIGN KEY (child_tag_id) REFERENCES tags(tag_id) ON DELETE CASCADE
);

-- ============================================================================
-- ANNOTATION & DRAWING TABLES
-- ============================================================================

-- Annotations: Visual drawings and diagrams on video
CREATE TABLE IF NOT EXISTS annotations (
    annotation_id TEXT PRIMARY KEY,
    video_id TEXT NOT NULL,
    tag_id TEXT, -- Optional: associate with specific tag/event
    timestamp_ms INTEGER NOT NULL,
    
    -- Visual properties
    annotation_type TEXT NOT NULL, -- line, arrow, circle, ellipse, polygon, rectangle, text, freehand, court_overlay
    coordinates TEXT NOT NULL, -- JSON array of points: [[x1,y1], [x2,y2], ...]
    color TEXT NOT NULL, -- Hex color: #FF0000
    thickness INTEGER DEFAULT 2,
    opacity REAL DEFAULT 1.0, -- 0.0 to 1.0
    fill_color TEXT, -- For shapes that can be filled
    fill_opacity REAL DEFAULT 0.3,
    
    -- Layer management
    layer_index INTEGER DEFAULT 0, -- Drawing order (higher = on top)
    layer_name TEXT, -- offense, defense, coaching_notes
    is_visible INTEGER DEFAULT 1,
    
    -- Text annotations
    text_content TEXT,
    font_size INTEGER DEFAULT 16,
    font_family TEXT DEFAULT 'SF Pro',
    
    -- Animation (for future keyframe feature)
    duration_ms INTEGER, -- How long annotation is visible
    animation_type TEXT, -- static, fade_in, fade_out, move
    
    -- Tracking
    created_by TEXT,
    created_at INTEGER NOT NULL,
    modified_at INTEGER,
    
    FOREIGN KEY (video_id) REFERENCES videos(video_id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(tag_id) ON DELETE CASCADE
);

-- Annotation Templates: Reusable annotation patterns (e.g., standard court overlays)
CREATE TABLE IF NOT EXISTS annotation_templates (
    template_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    template_type TEXT, -- court_overlay, defensive_scheme, offensive_play
    template_data TEXT NOT NULL, -- JSON: complete annotation structure
    thumbnail_path TEXT,
    created_at INTEGER NOT NULL,
    UNIQUE(name)
);

-- ============================================================================
-- PLAYLIST & PRESENTATION TABLES
-- ============================================================================

-- Playlists: Collections of clips for analysis or presentation
CREATE TABLE IF NOT EXISTS playlists (
    playlist_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    playlist_type TEXT DEFAULT 'analysis', -- analysis, scouting, presentation, player_development
    
    -- Auto-filter criteria (stored as JSON if auto-generated)
    filter_criteria TEXT, -- JSON: event_type, player_id, outcome, period, etc.
    is_auto_filtered INTEGER DEFAULT 0, -- 1 if auto-generated from criteria
    
    -- Organization
    category TEXT, -- offensive_sets, defensive_breakdowns, player_highlights
    tags TEXT, -- JSON array: ["pick-and-roll", "4th-quarter"]
    
    -- Sharing & collaboration
    created_by TEXT,
    is_shared INTEGER DEFAULT 0,
    share_url TEXT,
    
    -- Metadata
    thumbnail_path TEXT,
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    last_viewed_at INTEGER,
    
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE
);

-- Playlist Clips: Individual clips within playlists
CREATE TABLE IF NOT EXISTS playlist_clips (
    clip_id TEXT PRIMARY KEY,
    playlist_id TEXT NOT NULL,
    tag_id TEXT, -- Optional: reference to tagged event
    video_id TEXT NOT NULL, -- Direct video reference for manual clips
    
    -- Time boundaries
    start_time_ms INTEGER NOT NULL,
    end_time_ms INTEGER NOT NULL,
    
    -- Organization
    sort_order INTEGER NOT NULL, -- Position in playlist
    
    -- Trim and speed controls
    trim_start_ms INTEGER, -- Trim within the clip
    trim_end_ms INTEGER,
    playback_speed REAL DEFAULT 1.0, -- 0.25, 0.5, 1.0, 2.0, etc.
    
    -- Presentation options
    title TEXT, -- Clip title for presentations
    notes TEXT, -- Coaching notes for this clip
    transition_type TEXT DEFAULT 'none', -- none, fade, dissolve, cut
    transition_duration_ms INTEGER DEFAULT 500,
    
    -- Overlays
    show_annotations INTEGER DEFAULT 1,
    show_stats INTEGER DEFAULT 0,
    overlay_text TEXT, -- JSON: text overlays for presentation
    
    created_at INTEGER NOT NULL,
    
    FOREIGN KEY (playlist_id) REFERENCES playlists(playlist_id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(tag_id) ON DELETE SET NULL,
    FOREIGN KEY (video_id) REFERENCES videos(video_id) ON DELETE CASCADE
);

-- Presentations: Advanced presentation configurations (PRO feature)
CREATE TABLE IF NOT EXISTS presentations (
    presentation_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    
    -- Layout configuration
    layout_type TEXT DEFAULT 'single', -- single, side_by_side, quad, picture_in_picture
    layout_config TEXT, -- JSON: detailed layout configuration
    
    -- Presentation settings
    auto_play INTEGER DEFAULT 1,
    loop_clips INTEGER DEFAULT 0,
    show_controls INTEGER DEFAULT 1,
    
    -- Branding
    intro_video_path TEXT,
    outro_video_path TEXT,
    logo_path TEXT,
    brand_colors TEXT, -- JSON: primary, secondary colors
    
    -- Export settings
    export_resolution TEXT DEFAULT '1920x1080',
    export_format TEXT DEFAULT 'mp4',
    export_quality TEXT DEFAULT 'high',
    
    -- Voice-over (Live Coaching feature)
    has_voiceover INTEGER DEFAULT 0,
    voiceover_audio_path TEXT,
    
    -- Metadata
    created_by TEXT,
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    duration_ms INTEGER, -- Total presentation duration
    
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE
);

-- Presentation Sections: Organize presentations into sections
CREATE TABLE IF NOT EXISTS presentation_sections (
    section_id TEXT PRIMARY KEY,
    presentation_id TEXT NOT NULL,
    playlist_id TEXT, -- Link to playlist
    section_title TEXT NOT NULL,
    section_notes TEXT,
    sort_order INTEGER NOT NULL,
    layout_override TEXT, -- JSON: section-specific layout if different from presentation default
    created_at INTEGER NOT NULL,
    FOREIGN KEY (presentation_id) REFERENCES presentations(presentation_id) ON DELETE CASCADE,
    FOREIGN KEY (playlist_id) REFERENCES playlists(playlist_id) ON DELETE SET NULL
);

-- ============================================================================
-- STATISTICS & ANALYTICS TABLES
-- ============================================================================

-- Game Statistics: Aggregated stats per game
CREATE TABLE IF NOT EXISTS game_statistics (
    stat_id TEXT PRIMARY KEY,
    game_id TEXT NOT NULL,
    team_id TEXT NOT NULL,
    
    -- Shooting stats
    field_goals_made INTEGER DEFAULT 0,
    field_goals_attempted INTEGER DEFAULT 0,
    three_pointers_made INTEGER DEFAULT 0,
    three_pointers_attempted INTEGER DEFAULT 0,
    free_throws_made INTEGER DEFAULT 0,
    free_throws_attempted INTEGER DEFAULT 0,
    
    -- Rebound stats
    offensive_rebounds INTEGER DEFAULT 0,
    defensive_rebounds INTEGER DEFAULT 0,
    
    -- Playmaking stats
    assists INTEGER DEFAULT 0,
    turnovers INTEGER DEFAULT 0,
    
    -- Defensive stats
    steals INTEGER DEFAULT 0,
    blocks INTEGER DEFAULT 0,
    
    -- Other stats
    personal_fouls INTEGER DEFAULT 0,
    points_in_paint INTEGER DEFAULT 0,
    points_from_turnovers INTEGER DEFAULT 0,
    second_chance_points INTEGER DEFAULT 0,
    fast_break_points INTEGER DEFAULT 0,
    
    -- Possessions
    total_possessions INTEGER DEFAULT 0,
    
    -- Calculated at analysis time
    field_goal_percentage REAL,
    three_point_percentage REAL,
    free_throw_percentage REAL,
    effective_field_goal_percentage REAL,
    true_shooting_percentage REAL,
    assist_to_turnover_ratio REAL,
    
    calculated_at INTEGER,
    
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE,
    FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE,
    UNIQUE(game_id, team_id)
);

-- Player Statistics: Aggregated stats per player per game
CREATE TABLE IF NOT EXISTS player_statistics (
    stat_id TEXT PRIMARY KEY,
    game_id TEXT NOT NULL,
    player_id TEXT NOT NULL,
    
    -- Playing time
    minutes_played INTEGER DEFAULT 0,
    
    -- Shooting stats
    field_goals_made INTEGER DEFAULT 0,
    field_goals_attempted INTEGER DEFAULT 0,
    three_pointers_made INTEGER DEFAULT 0,
    three_pointers_attempted INTEGER DEFAULT 0,
    free_throws_made INTEGER DEFAULT 0,
    free_throws_attempted INTEGER DEFAULT 0,
    
    -- Rebound stats
    offensive_rebounds INTEGER DEFAULT 0,
    defensive_rebounds INTEGER DEFAULT 0,
    
    -- Playmaking stats
    assists INTEGER DEFAULT 0,
    turnovers INTEGER DEFAULT 0,
    
    -- Defensive stats
    steals INTEGER DEFAULT 0,
    blocks INTEGER DEFAULT 0,
    personal_fouls INTEGER DEFAULT 0,
    
    -- Advanced stats
    plus_minus INTEGER DEFAULT 0,
    points INTEGER DEFAULT 0,
    
    -- Zone shooting (JSON for flexibility)
    shooting_by_zone TEXT, -- JSON: {paint: {made: 5, attempted: 8}, mid_range: {...}, ...}
    
    calculated_at INTEGER,
    
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE,
    FOREIGN KEY (player_id) REFERENCES players(player_id) ON DELETE CASCADE,
    UNIQUE(game_id, player_id)
);

-- Shot Charts: Detailed shot location data
CREATE TABLE IF NOT EXISTS shot_charts (
    shot_id TEXT PRIMARY KEY,
    tag_id TEXT NOT NULL, -- Link to the shot tag
    game_id TEXT NOT NULL,
    player_id TEXT NOT NULL,
    
    -- Shot details
    shot_type TEXT NOT NULL, -- two_point, three_point, free_throw
    shot_made INTEGER NOT NULL, -- 1 = made, 0 = missed
    
    -- Location (normalized coordinates 0.0 to 1.0)
    court_x REAL NOT NULL, -- 0.0 = left, 1.0 = right
    court_y REAL NOT NULL, -- 0.0 = baseline, 1.0 = far baseline
    distance_feet REAL,
    zone TEXT, -- paint, mid_range, corner_three, wing_three, top_three
    
    -- Context
    assisted INTEGER DEFAULT 0,
    contested INTEGER DEFAULT 0,
    off_dribble INTEGER DEFAULT 0,
    catch_and_shoot INTEGER DEFAULT 0,
    
    timestamp_ms INTEGER NOT NULL,
    
    FOREIGN KEY (tag_id) REFERENCES tags(tag_id) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE,
    FOREIGN KEY (player_id) REFERENCES players(player_id) ON DELETE CASCADE
);

-- ============================================================================
-- IMPORT/EXPORT & INTEROPERABILITY TABLES
-- ============================================================================

-- Import History: Track imported data from other platforms
CREATE TABLE IF NOT EXISTS import_history (
    import_id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    source_platform TEXT NOT NULL, -- sportscode, catapult, nacsport, xml, csv
    source_file_path TEXT NOT NULL,
    import_type TEXT NOT NULL, -- tags, roster, game, full_project
    status TEXT NOT NULL, -- success, failed, partial
    records_imported INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    error_log TEXT, -- JSON array of errors
    imported_at INTEGER NOT NULL,
    imported_by TEXT,
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE
);

-- Export History: Track exported data
CREATE TABLE IF NOT EXISTS export_history (
    export_id TEXT PRIMARY KEY,
    project_id TEXT,
    export_type TEXT NOT NULL, -- playlist, tags, statistics, presentation, project
    target_format TEXT NOT NULL, -- mp4, xml, csv, json, sportscode, catapult
    file_path TEXT NOT NULL,
    file_size_bytes INTEGER,
    status TEXT NOT NULL, -- success, failed
    error_message TEXT,
    exported_at INTEGER NOT NULL,
    exported_by TEXT,
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE SET NULL
);

-- ============================================================================
-- SYSTEM & METADATA TABLES
-- ============================================================================

-- User Preferences: Per-user settings
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    email TEXT,
    
    -- UI preferences
    theme TEXT DEFAULT 'system', -- light, dark, system
    default_playback_speed REAL DEFAULT 1.0,
    hotkey_config TEXT, -- JSON: custom hotkey mappings
    
    -- Workflow preferences
    auto_save_interval_seconds INTEGER DEFAULT 30,
    default_tagging_template_id TEXT,
    default_video_quality TEXT DEFAULT 'high',
    
    -- Display preferences
    show_timeline_thumbnails INTEGER DEFAULT 1,
    show_game_clock INTEGER DEFAULT 1,
    show_shot_chart INTEGER DEFAULT 1,
    
    -- Preferences
    preferences TEXT, -- JSON: additional custom preferences
    
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,
    
    FOREIGN KEY (default_tagging_template_id) REFERENCES tagging_templates(template_id) ON DELETE SET NULL
);

-- App Metadata: Track app version, migrations, etc.
CREATE TABLE IF NOT EXISTS app_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at INTEGER NOT NULL
);

-- Sessions: Track analysis sessions for crash recovery
CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    project_id TEXT,
    game_id TEXT,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    status TEXT DEFAULT 'active', -- active, completed, crashed
    recovery_data TEXT, -- JSON: state data for crash recovery
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Projects
CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(name);
CREATE INDEX IF NOT EXISTS idx_projects_season ON projects(season);

-- Teams
CREATE INDEX IF NOT EXISTS idx_teams_project ON teams(project_id);
CREATE INDEX IF NOT EXISTS idx_teams_is_opponent ON teams(is_opponent);

-- Players
CREATE INDEX IF NOT EXISTS idx_players_team ON players(team_id);
CREATE INDEX IF NOT EXISTS idx_players_jersey ON players(jersey_number);
CREATE INDEX IF NOT EXISTS idx_players_position ON players(position);
CREATE INDEX IF NOT EXISTS idx_players_is_active ON players(is_active);

-- Games
CREATE INDEX IF NOT EXISTS idx_games_project ON games(project_id);
CREATE INDEX IF NOT EXISTS idx_games_date ON games(game_date);
CREATE INDEX IF NOT EXISTS idx_games_opponent ON games(opponent_team_id);
CREATE INDEX IF NOT EXISTS idx_games_type ON games(game_type);

-- Videos
CREATE INDEX IF NOT EXISTS idx_videos_game ON videos(game_id);
CREATE INDEX IF NOT EXISTS idx_videos_camera_angle ON videos(camera_angle);
CREATE INDEX IF NOT EXISTS idx_videos_is_primary ON videos(is_primary);

-- Clips
CREATE INDEX IF NOT EXISTS idx_clips_game ON clips(game_id);

-- Possessions
CREATE INDEX IF NOT EXISTS idx_possessions_game ON possessions(game_id);
CREATE INDEX IF NOT EXISTS idx_possessions_period ON possessions(period);
CREATE INDEX IF NOT EXISTS idx_possessions_team_type ON possessions(team_type);
CREATE INDEX IF NOT EXISTS idx_possessions_outcome ON possessions(outcome);
CREATE INDEX IF NOT EXISTS idx_possessions_start_time ON possessions(start_time_ms);

-- Tags (most frequently queried)
CREATE INDEX IF NOT EXISTS idx_tags_video ON tags(video_id);
CREATE INDEX IF NOT EXISTS idx_tags_game ON tags(game_id);
CREATE INDEX IF NOT EXISTS idx_tags_possession ON tags(possession_id);
CREATE INDEX IF NOT EXISTS idx_tags_timestamp ON tags(timestamp_ms);
CREATE INDEX IF NOT EXISTS idx_tags_player ON tags(player_id);
CREATE INDEX IF NOT EXISTS idx_tags_event_type ON tags(event_type);
CREATE INDEX IF NOT EXISTS idx_tags_event_category ON tags(event_category);
CREATE INDEX IF NOT EXISTS idx_tags_period ON tags(period);
CREATE INDEX IF NOT EXISTS idx_tags_outcome ON tags(outcome);
CREATE INDEX IF NOT EXISTS idx_tags_shot_zone ON tags(shot_zone);
CREATE INDEX IF NOT EXISTS idx_tags_offensive_set ON tags(offensive_set);
CREATE INDEX IF NOT EXISTS idx_tags_defensive_scheme ON tags(defensive_scheme);
CREATE INDEX IF NOT EXISTS idx_tags_is_transition ON tags(is_transition);
CREATE INDEX IF NOT EXISTS idx_tags_created_at ON tags(created_at);

-- Tag Links
CREATE INDEX IF NOT EXISTS idx_tag_links_parent ON tag_links(parent_tag_id);
CREATE INDEX IF NOT EXISTS idx_tag_links_child ON tag_links(child_tag_id);

-- Annotations
CREATE INDEX IF NOT EXISTS idx_annotations_video ON annotations(video_id);
CREATE INDEX IF NOT EXISTS idx_annotations_tag ON annotations(tag_id);
CREATE INDEX IF NOT EXISTS idx_annotations_timestamp ON annotations(timestamp_ms);
CREATE INDEX IF NOT EXISTS idx_annotations_layer ON annotations(layer_name);
CREATE INDEX IF NOT EXISTS idx_annotations_type ON annotations(annotation_type);

-- Playlists
CREATE INDEX IF NOT EXISTS idx_playlists_project ON playlists(project_id);
CREATE INDEX IF NOT EXISTS idx_playlists_type ON playlists(playlist_type);
CREATE INDEX IF NOT EXISTS idx_playlists_category ON playlists(category);
CREATE INDEX IF NOT EXISTS idx_playlists_created_by ON playlists(created_by);

-- Playlist Clips
CREATE INDEX IF NOT EXISTS idx_playlist_clips_playlist ON playlist_clips(playlist_id);
CREATE INDEX IF NOT EXISTS idx_playlist_clips_tag ON playlist_clips(tag_id);
CREATE INDEX IF NOT EXISTS idx_playlist_clips_video ON playlist_clips(video_id);
CREATE INDEX IF NOT EXISTS idx_playlist_clips_sort ON playlist_clips(sort_order);

-- Statistics
CREATE INDEX IF NOT EXISTS idx_game_stats_game ON game_statistics(game_id);
CREATE INDEX IF NOT EXISTS idx_game_stats_team ON game_statistics(team_id);
CREATE INDEX IF NOT EXISTS idx_player_stats_game ON player_statistics(game_id);
CREATE INDEX IF NOT EXISTS idx_player_stats_player ON player_statistics(player_id);

-- Shot Charts
CREATE INDEX IF NOT EXISTS idx_shot_charts_tag ON shot_charts(tag_id);
CREATE INDEX IF NOT EXISTS idx_shot_charts_game ON shot_charts(game_id);
CREATE INDEX IF NOT EXISTS idx_shot_charts_player ON shot_charts(player_id);
CREATE INDEX IF NOT EXISTS idx_shot_charts_zone ON shot_charts(zone);
CREATE INDEX IF NOT EXISTS idx_shot_charts_made ON shot_charts(shot_made);

-- Import/Export
CREATE INDEX IF NOT EXISTS idx_import_history_project ON import_history(project_id);
CREATE INDEX IF NOT EXISTS idx_import_history_platform ON import_history(source_platform);
CREATE INDEX IF NOT EXISTS idx_export_history_project ON export_history(project_id);
CREATE INDEX IF NOT EXISTS idx_export_history_type ON export_history(export_type);

-- Sessions
CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project_id);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status);

-- ============================================================================
-- INITIAL DATA & METADATA
-- ============================================================================

-- Set database version
INSERT INTO app_metadata (key, value, updated_at) 
VALUES ('schema_version', '1.0.0', strftime('%s', 'now') * 1000);

INSERT INTO app_metadata (key, value, updated_at) 
VALUES ('created_at', datetime('now'), strftime('%s', 'now') * 1000);

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================

