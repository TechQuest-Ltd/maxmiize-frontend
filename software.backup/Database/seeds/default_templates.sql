-- ============================================================================
-- MAXMIIZE DEFAULT DATA SEEDS
-- Basketball tagging templates and annotation templates
-- ============================================================================

-- ============================================================================
-- DEFAULT BASKETBALL TAGGING TEMPLATE
-- ============================================================================

INSERT INTO tagging_templates (
    template_id,
    project_id,
    name,
    description,
    sport,
    template_data,
    is_default,
    created_at,
    modified_at
) VALUES (
    'template-basketball-full',
    NULL,  -- Global template
    'Basketball - Full Game Analysis',
    'Complete basketball tagging template with all event types, hotkeys, and metadata',
    'basketball',
    '{
        "version": "1.0",
        "categories": [
            {
                "id": "offense",
                "name": "Offense",
                "color": "#3B82F6",
                "hotkey": "O",
                "events": [
                    {
                        "id": "shot_paint",
                        "name": "Shot - Paint",
                        "hotkey": "P",
                        "outcomes": ["made", "missed"],
                        "metadata": ["player", "assisted", "offensive_set"]
                    },
                    {
                        "id": "shot_midrange",
                        "name": "Shot - Mid-Range",
                        "hotkey": "M",
                        "outcomes": ["made", "missed"],
                        "metadata": ["player", "assisted", "location", "offensive_set"]
                    },
                    {
                        "id": "shot_three",
                        "name": "Shot - Three-Point",
                        "hotkey": "3",
                        "outcomes": ["made", "missed"],
                        "metadata": ["player", "assisted", "zone", "offensive_set"]
                    },
                    {
                        "id": "shot_freethrow",
                        "name": "Free Throw",
                        "hotkey": "F",
                        "outcomes": ["made", "missed"],
                        "metadata": ["player", "foul_type"]
                    },
                    {
                        "id": "assist",
                        "name": "Assist",
                        "hotkey": "A",
                        "metadata": ["passer", "scorer", "assist_type"]
                    },
                    {
                        "id": "offensive_rebound",
                        "name": "Offensive Rebound",
                        "hotkey": "R",
                        "metadata": ["player", "contested"]
                    },
                    {
                        "id": "turnover",
                        "name": "Turnover",
                        "hotkey": "T",
                        "subtypes": [
                            {"id": "bad_pass", "name": "Bad Pass", "hotkey": "1"},
                            {"id": "traveling", "name": "Traveling", "hotkey": "2"},
                            {"id": "offensive_foul", "name": "Offensive Foul", "hotkey": "3"},
                            {"id": "shot_clock", "name": "Shot Clock Violation", "hotkey": "4"},
                            {"id": "double_dribble", "name": "Double Dribble", "hotkey": "5"},
                            {"id": "three_second", "name": "3-Second Violation", "hotkey": "6"},
                            {"id": "backcourt", "name": "Backcourt Violation", "hotkey": "7"},
                            {"id": "other", "name": "Other", "hotkey": "8"}
                        ],
                        "metadata": ["player", "result"]
                    }
                ]
            },
            {
                "id": "defense",
                "name": "Defense",
                "color": "#EF4444",
                "hotkey": "D",
                "events": [
                    {
                        "id": "defensive_rebound",
                        "name": "Defensive Rebound",
                        "hotkey": "R",
                        "metadata": ["player", "contested"]
                    },
                    {
                        "id": "steal",
                        "name": "Steal",
                        "hotkey": "S",
                        "metadata": ["player", "resulted_in"]
                    },
                    {
                        "id": "block",
                        "name": "Block",
                        "hotkey": "B",
                        "metadata": ["player", "shot_type"]
                    },
                    {
                        "id": "deflection",
                        "name": "Deflection",
                        "hotkey": "L",
                        "metadata": ["player"]
                    },
                    {
                        "id": "foul",
                        "name": "Foul",
                        "hotkey": "F",
                        "subtypes": [
                            {"id": "shooting", "name": "Shooting Foul", "hotkey": "1"},
                            {"id": "personal", "name": "Personal Foul", "hotkey": "2"},
                            {"id": "technical", "name": "Technical Foul", "hotkey": "3"},
                            {"id": "flagrant", "name": "Flagrant Foul", "hotkey": "4"}
                        ],
                        "metadata": ["player", "opponent_player", "free_throws"]
                    }
                ]
            },
            {
                "id": "transition",
                "name": "Transition",
                "color": "#10B981",
                "hotkey": "Z",
                "events": [
                    {
                        "id": "fast_break",
                        "name": "Fast Break",
                        "hotkey": "F",
                        "outcomes": ["score", "no_score"],
                        "metadata": ["players_involved", "result"]
                    },
                    {
                        "id": "transition_defense",
                        "name": "Transition Defense",
                        "hotkey": "D",
                        "outcomes": ["stop", "score_allowed"],
                        "metadata": ["quality"]
                    }
                ]
            },
            {
                "id": "special",
                "name": "Special Situations",
                "color": "#8B5CF6",
                "hotkey": "X",
                "events": [
                    {
                        "id": "timeout",
                        "name": "Timeout",
                        "hotkey": "T",
                        "metadata": ["team", "duration"]
                    },
                    {
                        "id": "substitution",
                        "name": "Substitution",
                        "hotkey": "S",
                        "metadata": ["player_in", "player_out"]
                    },
                    {
                        "id": "technical",
                        "name": "Technical Event",
                        "hotkey": "C",
                        "metadata": ["description"]
                    }
                ]
            }
        ],
        "offensive_sets": [
            "pick_and_roll",
            "pick_and_pop",
            "motion_offense",
            "horns_set",
            "princeton_offense",
            "isolation",
            "post_up",
            "flex_offense",
            "triangle_offense",
            "dribble_handoff",
            "spain_pick_and_roll",
            "elevator_screen",
            "other"
        ],
        "defensive_schemes": [
            "man_to_man",
            "zone_2_3",
            "zone_3_2",
            "zone_1_3_1",
            "zone_1_2_2",
            "matchup_zone",
            "press_full_court",
            "press_three_quarter",
            "press_half_court",
            "box_and_one",
            "triangle_and_two",
            "pack_line",
            "other"
        ],
        "shot_zones": [
            "paint",
            "mid_range",
            "corner_three_left",
            "corner_three_right",
            "wing_three_left",
            "wing_three_right",
            "top_three"
        ]
    }',
    1,
    strftime('%s', 'now') * 1000,
    strftime('%s', 'now') * 1000
);

-- ============================================================================
-- SIMPLIFIED LIVE TAGGING TEMPLATE
-- ============================================================================

INSERT INTO tagging_templates (
    template_id,
    project_id,
    name,
    description,
    sport,
    template_data,
    is_default,
    created_at,
    modified_at
) VALUES (
    'template-basketball-live',
    NULL,
    'Basketball - Live Game (Quick Tag)',
    'Simplified template optimized for real-time tagging during live games',
    'basketball',
    '{
        "version": "1.0",
        "categories": [
            {
                "id": "scoring",
                "name": "Scoring",
                "color": "#3B82F6",
                "events": [
                    {"id": "two_made", "name": "2PT Made", "hotkey": "2", "points": 2},
                    {"id": "two_missed", "name": "2PT Missed", "hotkey": "Shift+2", "points": 0},
                    {"id": "three_made", "name": "3PT Made", "hotkey": "3", "points": 3},
                    {"id": "three_missed", "name": "3PT Missed", "hotkey": "Shift+3", "points": 0},
                    {"id": "ft_made", "name": "FT Made", "hotkey": "F", "points": 1},
                    {"id": "ft_missed", "name": "FT Missed", "hotkey": "Shift+F", "points": 0}
                ]
            },
            {
                "id": "key_events",
                "name": "Key Events",
                "color": "#EF4444",
                "events": [
                    {"id": "turnover", "name": "Turnover", "hotkey": "T"},
                    {"id": "steal", "name": "Steal", "hotkey": "S"},
                    {"id": "block", "name": "Block", "hotkey": "B"},
                    {"id": "assist", "name": "Assist", "hotkey": "A"},
                    {"id": "rebound_off", "name": "Off Reb", "hotkey": "O"},
                    {"id": "rebound_def", "name": "Def Reb", "hotkey": "D"}
                ]
            }
        ]
    }',
    0,
    strftime('%s', 'now') * 1000,
    strftime('%s', 'now') * 1000
);

-- ============================================================================
-- ANNOTATION TEMPLATES
-- ============================================================================

-- Half-Court Overlay
INSERT INTO annotation_templates (
    template_id,
    name,
    description,
    template_type,
    template_data,
    created_at
) VALUES (
    'court-half-court',
    'Half Court Overlay',
    'Standard half-court basketball court overlay with three-point line, paint, and free throw line',
    'court_overlay',
    '{
        "court_type": "half_court",
        "orientation": "right",
        "elements": [
            {
                "type": "rectangle",
                "id": "paint",
                "coordinates": [[0.35, 0.15], [0.51, 0.85]],
                "color": "#FFFFFF",
                "thickness": 2,
                "fill": false
            },
            {
                "type": "circle",
                "id": "free_throw_circle",
                "center": [0.35, 0.5],
                "radius": 0.08,
                "color": "#FFFFFF",
                "thickness": 2,
                "fill": false
            },
            {
                "type": "arc",
                "id": "three_point_line",
                "center": [0.58, 0.5],
                "radius": 0.32,
                "start_angle": -67,
                "end_angle": 67,
                "color": "#FFFFFF",
                "thickness": 2
            },
            {
                "type": "line",
                "id": "baseline",
                "coordinates": [[0.1, 0.1], [0.1, 0.9]],
                "color": "#FFFFFF",
                "thickness": 2
            },
            {
                "type": "line",
                "id": "three_point_corner_left",
                "coordinates": [[0.1, 0.1], [0.26, 0.1]],
                "color": "#FFFFFF",
                "thickness": 2
            },
            {
                "type": "line",
                "id": "three_point_corner_right",
                "coordinates": [[0.1, 0.9], [0.26, 0.9]],
                "color": "#FFFFFF",
                "thickness": 2
            }
        ]
    }',
    strftime('%s', 'now') * 1000
);

-- Full Court Overlay
INSERT INTO annotation_templates (
    template_id,
    name,
    description,
    template_type,
    template_data,
    created_at
) VALUES (
    'court-full-court',
    'Full Court Overlay',
    'Full basketball court overlay for transition analysis',
    'court_overlay',
    '{
        "court_type": "full_court",
        "elements": [
            {
                "type": "line",
                "id": "half_court_line",
                "coordinates": [[0.5, 0.1], [0.5, 0.9]],
                "color": "#FFFFFF",
                "thickness": 2
            },
            {
                "type": "circle",
                "id": "center_circle",
                "center": [0.5, 0.5],
                "radius": 0.08,
                "color": "#FFFFFF",
                "thickness": 2,
                "fill": false
            }
        ]
    }',
    strftime('%s', 'now') * 1000
);

-- Pick and Roll Annotation
INSERT INTO annotation_templates (
    template_id,
    name,
    description,
    template_type,
    template_data,
    created_at
) VALUES (
    'play-pick-and-roll',
    'Pick and Roll',
    'Standard pick and roll play diagram',
    'offensive_play',
    '{
        "annotations": [
            {
                "type": "circle",
                "label": "Ball Handler",
                "color": "#3B82F6",
                "default_position": [0.4, 0.5]
            },
            {
                "type": "circle",
                "label": "Screener",
                "color": "#3B82F6",
                "default_position": [0.35, 0.5]
            },
            {
                "type": "arrow",
                "label": "Screen",
                "color": "#10B981",
                "from": [0.35, 0.5],
                "to": [0.38, 0.5]
            },
            {
                "type": "arrow",
                "label": "Roll",
                "color": "#EF4444",
                "from": [0.38, 0.5],
                "to": [0.25, 0.5],
                "style": "curved"
            }
        ]
    }',
    strftime('%s', 'now') * 1000
);

-- ============================================================================
-- DEFAULT USER PREFERENCES
-- ============================================================================

INSERT INTO user_preferences (
    user_id,
    username,
    theme,
    default_playback_speed,
    auto_save_interval_seconds,
    default_tagging_template_id,
    show_timeline_thumbnails,
    show_game_clock,
    show_shot_chart,
    created_at,
    modified_at
) VALUES (
    'default-user',
    'Default User',
    'system',
    1.0,
    30,
    'template-basketball-full',
    1,
    1,
    1,
    strftime('%s', 'now') * 1000,
    strftime('%s', 'now') * 1000
);

-- ============================================================================
-- END OF SEED DATA
-- ============================================================================

