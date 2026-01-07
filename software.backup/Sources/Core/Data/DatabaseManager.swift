//
//  DatabaseManager.swift
//  maxmiize-v1
//
//  Created by TechQuest on 12/12/2025.
//

import Foundation
import SQLite3

enum DatabaseError: Error {
    case openFailed(String)
    case prepareFailed(String)
    case executionFailed(String)
    case noDatabase
    case videoMetadataExtractionFailed(String)
    case connectionError
    case serializationError
    case queryPreparationFailed
    case insertFailed
    case updateFailed
    case deleteFailed

    var localizedDescription: String {
        switch self {
        case .openFailed(let message):
            return "Failed to open database: \(message)"
        case .prepareFailed(let message):
            return "Failed to prepare SQL statement: \(message)"
        case .executionFailed(let message):
            return "Failed to execute query: \(message)"
        case .noDatabase:
            return "Database connection not available"
        case .videoMetadataExtractionFailed(let message):
            return "Failed to extract video metadata: \(message)"
        case .connectionError:
            return "Database connection error"
        case .serializationError:
            return "Failed to serialize data"
        case .queryPreparationFailed:
            return "Failed to prepare database query"
        case .insertFailed:
            return "Failed to insert record"
        case .updateFailed:
            return "Failed to update record"
        case .deleteFailed:
            return "Failed to delete record"
        }
    }
}

class DatabaseManager {
    nonisolated(unsafe) static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private var dbPath: String
    private let dbQueue = DispatchQueue(label: "com.maxmiize.database", qos: .userInitiated)

    private init() {
        // Store database in Application Support directory
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("com.maxmiize.maxmiize-v1", isDirectory: true)

        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        dbPath = appDirectory.appendingPathComponent("maxmiize.db").path

        openDatabase()
        createTables()
    }

    /// Initialize database at a custom path (for project bundles)
    func initializeDatabase(at customPath: String) {
        // Close existing database if open
        if db != nil {
            sqlite3_close(db)
            db = nil
        }

        // Store the current database path
        dbPath = customPath

        // Open database at custom path
        if sqlite3_open(customPath, &db) != SQLITE_OK {
            print("❌ Error opening database at \(customPath)")
        } else {
            print("✅ Successfully opened database at \(customPath)")
            print("   📍 Current database path stored: \(dbPath)")

            // Enable foreign keys
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, "PRAGMA foreign_keys = ON;", -1, &statement, nil) == SQLITE_OK {
                sqlite3_step(statement)
                sqlite3_finalize(statement)
            }

            // Enable WAL mode for better concurrency and persistence
            if sqlite3_prepare_v2(db, "PRAGMA journal_mode = WAL;", -1, &statement, nil) == SQLITE_OK {
                sqlite3_step(statement)
                sqlite3_finalize(statement)
                print("✅ Enabled WAL mode")
            }

            // Set synchronous to NORMAL for balance between speed and safety
            if sqlite3_prepare_v2(db, "PRAGMA synchronous = NORMAL;", -1, &statement, nil) == SQLITE_OK {
                sqlite3_step(statement)
                sqlite3_finalize(statement)
                print("✅ Set synchronous mode to NORMAL")
            }

            // Create tables if they don't exist
            createTables()

            // Run migrations to add new tables
            runMigrations()
        }
    }

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database at \(dbPath)")
        } else {
            print("Successfully opened database at \(dbPath)")

            // Enable foreign keys
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, "PRAGMA foreign_keys = ON;", -1, &statement, nil) == SQLITE_OK {
                sqlite3_step(statement)
                sqlite3_finalize(statement)
            }

            // Enable WAL mode for better concurrency and persistence
            if sqlite3_prepare_v2(db, "PRAGMA journal_mode = WAL;", -1, &statement, nil) == SQLITE_OK {
                sqlite3_step(statement)
                sqlite3_finalize(statement)
                print("✅ Enabled WAL mode")
            }

            // Set synchronous to NORMAL for balance between speed and safety
            if sqlite3_prepare_v2(db, "PRAGMA synchronous = NORMAL;", -1, &statement, nil) == SQLITE_OK {
                sqlite3_step(statement)
                sqlite3_finalize(statement)
                print("✅ Set synchronous mode to NORMAL")
            }
        }
    }

    private func createTables() {
        // Try to load from bundle first
        var schemaSQL: String?

        if let schemaURL = Bundle.main.url(forResource: "schema", withExtension: "sql", subdirectory: "Database"),
           let content = try? String(contentsOf: schemaURL, encoding: .utf8) {
            schemaSQL = content
            print("✅ Loaded schema from bundle")
        } else {
            // Fallback: Use embedded schema for essential tables
            print("⚠️ schema.sql not in bundle, using embedded schema")
            schemaSQL = getEmbeddedSchema()
        }

        guard let finalSchema = schemaSQL else {
            print("❌ ERROR: No schema available")
            return
        }

        // Execute schema
        var error: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, finalSchema, nil, nil, &error) != SQLITE_OK {
            let errorMessage = String(cString: error!)
            print("❌ ERROR creating tables: \(errorMessage)")
            sqlite3_free(error)
        } else {
            print("✅ Database schema created successfully")
        }
    }

    private func runMigrations() {
        guard let db = db else {
            print("❌ DatabaseManager.runMigrations: No database connection")
            return
        }

        print("🔄 Running database migrations...")

        // Migration 1: Add possessions table
        let possessionsMigration = """
        CREATE TABLE IF NOT EXISTS possessions (
            possession_id TEXT PRIMARY KEY,
            game_id TEXT NOT NULL,
            team_type TEXT NOT NULL,
            start_time_ms INTEGER NOT NULL,
            end_time_ms INTEGER,
            period INTEGER NOT NULL,
            start_trigger TEXT NOT NULL,
            end_trigger TEXT,
            outcome TEXT,
            points_scored INTEGER DEFAULT 0,
            tag_count INTEGER DEFAULT 0,
            duration_ms INTEGER,
            notes TEXT,
            created_at INTEGER NOT NULL,
            modified_at INTEGER,
            FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
        );
        """

        // Migration 2: Recreate tags table with new schema (time-based events that create timeline rows)
        let tagsMigration = """
        -- Drop old tags table if it exists (data will be lost as per user instruction)
        DROP TABLE IF EXISTS tags;
        DROP TABLE IF EXISTS labels;

        -- Create new tags table with tag_category schema
        CREATE TABLE tags (
            tag_id TEXT PRIMARY KEY,
            game_id TEXT NOT NULL,
            tag_category TEXT NOT NULL,  -- "Offense", "Defense", "Player Minutes", custom categories
            start_timestamp_ms INTEGER NOT NULL,
            end_timestamp_ms INTEGER,  -- NULL if tag is still active
            duration_ms INTEGER,  -- Calculated when tag ends
            notes TEXT,
            created_at INTEGER NOT NULL,
            modified_at INTEGER,
            FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
        );

        -- Labels table: Descriptive metadata attached to tags
        CREATE TABLE labels (
            label_id TEXT PRIMARY KEY,
            tag_id TEXT NOT NULL,
            label_type TEXT NOT NULL,  -- "Transition", "Shot", "3-Point", "Made", "Assist", etc.
            timestamp_ms INTEGER,  -- When during the tag this label was added (relative to tag start)
            value TEXT,  -- Optional value (e.g., player name, score)
            created_at INTEGER NOT NULL,
            FOREIGN KEY (tag_id) REFERENCES tags(tag_id) ON DELETE CASCADE
        );
        """

        // Migration 3: Add indexes for tags and labels
        let tagsIndexesMigration = """
        CREATE INDEX IF NOT EXISTS idx_tags_game ON tags(game_id);
        CREATE INDEX IF NOT EXISTS idx_tags_category ON tags(tag_category);
        CREATE INDEX IF NOT EXISTS idx_tags_start_time ON tags(start_timestamp_ms);
        CREATE INDEX IF NOT EXISTS idx_labels_tag ON labels(tag_id);
        CREATE INDEX IF NOT EXISTS idx_labels_type ON labels(label_type);
        """

        // Migration 4: Add indexes for possessions
        let possessionsIndexesMigration = """
        CREATE INDEX IF NOT EXISTS idx_possessions_game ON possessions(game_id);
        CREATE INDEX IF NOT EXISTS idx_possessions_period ON possessions(period);
        CREATE INDEX IF NOT EXISTS idx_possessions_team_type ON possessions(team_type);
        CREATE INDEX IF NOT EXISTS idx_possessions_start_time ON possessions(start_time_ms);
        """

        // Migration 5: Add annotations table
        let annotationsMigration = """
        CREATE TABLE IF NOT EXISTS annotations (
            annotation_id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            video_id TEXT,
            angle_id TEXT NOT NULL,
            annotation_type TEXT NOT NULL,
            annotation_data TEXT NOT NULL,
            start_time_ms INTEGER NOT NULL,
            end_time_ms INTEGER NOT NULL,
            color TEXT NOT NULL,
            stroke_width REAL NOT NULL,
            opacity REAL NOT NULL,
            is_visible INTEGER DEFAULT 1,
            is_locked INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            modified_at INTEGER,
            FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE,
            FOREIGN KEY (video_id) REFERENCES videos(video_id) ON DELETE CASCADE
        );
        """

        // Migration 6: Add indexes for annotations
        let annotationsIndexesMigration = """
        CREATE INDEX IF NOT EXISTS idx_annotations_project ON annotations(project_id);
        CREATE INDEX IF NOT EXISTS idx_annotations_video ON annotations(video_id);
        CREATE INDEX IF NOT EXISTS idx_annotations_angle ON annotations(angle_id);
        CREATE INDEX IF NOT EXISTS idx_annotations_start_time ON annotations(start_time_ms);
        CREATE INDEX IF NOT EXISTS idx_annotations_type ON annotations(annotation_type);
        """

        // Migration 7: Add blueprints table
        let blueprintsMigration = """
        CREATE TABLE IF NOT EXISTS blueprints (
            blueprint_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            moments_json TEXT NOT NULL,
            layers_json TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            modified_at INTEGER,
            is_default INTEGER DEFAULT 0
        );
        """

        // Migration 8: Add indexes for blueprints
        let blueprintsIndexesMigration = """
        CREATE INDEX IF NOT EXISTS idx_blueprints_name ON blueprints(name);
        CREATE INDEX IF NOT EXISTS idx_blueprints_is_default ON blueprints(is_default);
        """

        // Migration 9: Add notes table
        let notesMigration = """
        CREATE TABLE IF NOT EXISTS notes (
            note_id TEXT PRIMARY KEY,
            moment_id TEXT NOT NULL,
            game_id TEXT NOT NULL,
            content TEXT NOT NULL,
            attached_to TEXT NOT NULL,
            player_id TEXT,
            created_at INTEGER NOT NULL,
            modified_at INTEGER,
            FOREIGN KEY (moment_id) REFERENCES tags(tag_id) ON DELETE CASCADE,
            FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
        );
        """

        // Migration 10: Add indexes for notes
        let notesIndexesMigration = """
        CREATE INDEX IF NOT EXISTS idx_notes_moment ON notes(moment_id);
        CREATE INDEX IF NOT EXISTS idx_notes_game ON notes(game_id);
        CREATE INDEX IF NOT EXISTS idx_notes_player ON notes(player_id);
        """

        // Migration 11: Add categories table
        let categoriesMigration = """
        CREATE TABLE IF NOT EXISTS categories (
            category_id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            color TEXT NOT NULL,
            sort_order INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            modified_at INTEGER
        );

        -- Seed default categories
        INSERT OR IGNORE INTO categories (category_id, name, color, sort_order, created_at)
        VALUES
            ('default-offense', 'Offense', '5adc8c', 0, strftime('%s', 'now') * 1000),
            ('default-defense', 'Defense', 'ff5252', 1, strftime('%s', 'now') * 1000);
        """

        // Migration 12: Add indexes for categories
        let categoriesIndexesMigration = """
        CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);
        CREATE INDEX IF NOT EXISTS idx_categories_sort_order ON categories(sort_order);
        """

        // Migration 13: Make moment_id nullable in notes table
        let notesNullableMomentIdMigration = """
        -- Create new notes table with nullable moment_id
        CREATE TABLE IF NOT EXISTS notes_new (
            note_id TEXT PRIMARY KEY,
            moment_id TEXT,
            game_id TEXT NOT NULL,
            content TEXT NOT NULL,
            attached_to TEXT NOT NULL,
            player_id TEXT,
            created_at INTEGER NOT NULL,
            modified_at INTEGER,
            FOREIGN KEY (moment_id) REFERENCES tags(tag_id) ON DELETE CASCADE,
            FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
        );

        -- Copy existing data
        INSERT INTO notes_new SELECT * FROM notes;

        -- Drop old table
        DROP TABLE notes;

        -- Rename new table
        ALTER TABLE notes_new RENAME TO notes;
        """

        // Migration 14: Re-add indexes for notes after schema change
        let notesIndexesRebuildMigration = """
        CREATE INDEX IF NOT EXISTS idx_notes_moment ON notes(moment_id);
        CREATE INDEX IF NOT EXISTS idx_notes_game ON notes(game_id);
        CREATE INDEX IF NOT EXISTS idx_notes_player ON notes(player_id);
        """

        // Migration 13: Add playlists table
        let playlistsMigration = """
        CREATE TABLE IF NOT EXISTS playlists (
            playlist_id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            name TEXT NOT NULL,
            purpose TEXT NOT NULL,
            description TEXT,
            filter_criteria TEXT,
            clip_ids TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            modified_at INTEGER,
            FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE
        );
        """

        // Migration 14: Add indexes for playlists
        let playlistsIndexesMigration = """
        CREATE INDEX IF NOT EXISTS idx_playlists_project ON playlists(project_id);
        CREATE INDEX IF NOT EXISTS idx_playlists_purpose ON playlists(purpose);
        CREATE INDEX IF NOT EXISTS idx_playlists_created_at ON playlists(created_at);
        """

        // Migration 15: Add moment_players junction table
        let momentPlayersMigration = """
        CREATE TABLE IF NOT EXISTS moment_players (
            moment_id TEXT NOT NULL,
            player_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (moment_id, player_id),
            FOREIGN KEY (moment_id) REFERENCES tags(tag_id) ON DELETE CASCADE,
            FOREIGN KEY (player_id) REFERENCES players(player_id) ON DELETE CASCADE
        );
        """

        // Migration 16: Add indexes for moment_players
        let momentPlayersIndexesMigration = """
        CREATE INDEX IF NOT EXISTS idx_moment_players_moment ON moment_players(moment_id);
        CREATE INDEX IF NOT EXISTS idx_moment_players_player ON moment_players(player_id);
        """

        // Create migrations tracking table
        let createMigrationsTable = """
        CREATE TABLE IF NOT EXISTS schema_migrations (
            migration_name TEXT PRIMARY KEY,
            applied_at INTEGER NOT NULL
        );
        """
        var error: UnsafeMutablePointer<Int8>?
        sqlite3_exec(db, createMigrationsTable, nil, nil, &error)

        // Execute migrations only if not already applied
        let migrations = [
            ("possessions", possessionsMigration),
            ("tags", tagsMigration),
            ("tags_indexes", tagsIndexesMigration),
            ("possessions_indexes", possessionsIndexesMigration),
            ("annotations", annotationsMigration),
            ("annotations_indexes", annotationsIndexesMigration),
            ("blueprints", blueprintsMigration),
            ("blueprints_indexes", blueprintsIndexesMigration),
            ("notes", notesMigration),
            ("notes_indexes", notesIndexesMigration),
            ("categories", categoriesMigration),
            ("categories_indexes", categoriesIndexesMigration),
            ("notes_nullable_moment_id", notesNullableMomentIdMigration),
            ("notes_indexes_rebuild", notesIndexesRebuildMigration),
            ("playlists", playlistsMigration),
            ("playlists_indexes", playlistsIndexesMigration),
            ("moment_players", momentPlayersMigration),
            ("moment_players_indexes", momentPlayersIndexesMigration)
        ]

        for (name, sql) in migrations {
            // Check if migration already applied
            let checkQuery = "SELECT 1 FROM schema_migrations WHERE migration_name = ?"
            var statement: OpaquePointer?

            if sqlite3_prepare_v2(db, checkQuery, -1, &statement, nil) == SQLITE_OK {
                let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                name.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

                let alreadyApplied = sqlite3_step(statement) == SQLITE_ROW
                sqlite3_finalize(statement)

                if alreadyApplied {
                    print("⏭️  Migration '\(name)' already applied, skipping")
                    continue
                }
            }

            // Run migration
            var migrationError: UnsafeMutablePointer<Int8>?
            if sqlite3_exec(db, sql, nil, nil, &migrationError) != SQLITE_OK {
                if let migrationError = migrationError {
                    let errorMessage = String(cString: migrationError)
                    print("❌ Migration '\(name)' failed: \(errorMessage)")
                    sqlite3_free(migrationError)
                }
            } else {
                // Mark migration as applied
                let insertQuery = "INSERT INTO schema_migrations (migration_name, applied_at) VALUES (?, ?)"
                var insertStatement: OpaquePointer?
                if sqlite3_prepare_v2(db, insertQuery, -1, &insertStatement, nil) == SQLITE_OK {
                    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                    let now = Int64(Date().timeIntervalSince1970 * 1000)
                    name.withCString { sqlite3_bind_text(insertStatement, 1, $0, -1, SQLITE_TRANSIENT) }
                    sqlite3_bind_int64(insertStatement, 2, now)
                    sqlite3_step(insertStatement)
                    sqlite3_finalize(insertStatement)
                }
                print("✅ Migration '\(name)' completed")
            }
        }

        print("✅ Database migrations completed")
    }

    private func getEmbeddedSchema() -> String {
        return """
        PRAGMA foreign_keys = ON;

        -- Projects table
        CREATE TABLE IF NOT EXISTS projects (
            project_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            season TEXT,
            sport TEXT DEFAULT 'basketball',
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL,
            settings TEXT,
            UNIQUE(name, season)
        );

        -- Games table
        CREATE TABLE IF NOT EXISTS games (
            game_id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            opponent_team_id TEXT,
            game_date INTEGER NOT NULL,
            game_time TEXT,
            location TEXT,
            is_home_game INTEGER NOT NULL DEFAULT 1,
            final_score_us INTEGER,
            final_score_opponent INTEGER,
            overtime_periods INTEGER DEFAULT 0,
            game_type TEXT,
            game_notes TEXT,
            weather_conditions TEXT,
            attendance INTEGER,
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL,
            FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE
        );

        -- Videos table
        CREATE TABLE IF NOT EXISTS videos (
            video_id TEXT PRIMARY KEY,
            game_id TEXT NOT NULL,
            file_path TEXT NOT NULL,
            file_size_bytes INTEGER,
            camera_angle TEXT NOT NULL,
            duration_ms INTEGER NOT NULL,
            frame_rate REAL NOT NULL,
            resolution_width INTEGER NOT NULL,
            resolution_height INTEGER NOT NULL,
            codec TEXT NOT NULL,
            bitrate_kbps INTEGER,
            is_primary INTEGER DEFAULT 0,
            timecode_offset_ms INTEGER DEFAULT 0,
            import_date INTEGER NOT NULL,
            thumbnail_path TEXT,
            metadata TEXT,
            FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
        );

        -- Teams table
        CREATE TABLE IF NOT EXISTS teams (
            team_id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            name TEXT NOT NULL,
            is_opponent INTEGER NOT NULL DEFAULT 0,
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

        -- Players table
        CREATE TABLE IF NOT EXISTS players (
            player_id TEXT PRIMARY KEY,
            team_id TEXT NOT NULL,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            jersey_number INTEGER NOT NULL,
            position TEXT,
            height_inches INTEGER,
            weight_lbs INTEGER,
            class_year TEXT,
            birth_date TEXT,
            notes TEXT,
            is_active INTEGER DEFAULT 1,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE,
            UNIQUE(team_id, jersey_number)
        );

        -- Clips table
        CREATE TABLE IF NOT EXISTS clips (
            clip_id TEXT PRIMARY KEY,
            game_id TEXT NOT NULL,
            start_time_ms INTEGER NOT NULL,
            end_time_ms INTEGER NOT NULL,
            title TEXT NOT NULL,
            notes TEXT,
            tags TEXT,
            thumbnail_path TEXT,
            created_at INTEGER NOT NULL,
            modified_at INTEGER,
            FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
        );

        -- Clip-Player junction table (many-to-many relationship)
        CREATE TABLE IF NOT EXISTS clip_players (
            clip_id TEXT NOT NULL,
            player_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (clip_id, player_id),
            FOREIGN KEY (clip_id) REFERENCES clips(clip_id) ON DELETE CASCADE,
            FOREIGN KEY (player_id) REFERENCES players(player_id) ON DELETE CASCADE
        );

        -- App metadata table
        CREATE TABLE IF NOT EXISTS app_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
        );

        -- Indexes
        CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(name);
        CREATE INDEX IF NOT EXISTS idx_games_project ON games(project_id);
        CREATE INDEX IF NOT EXISTS idx_videos_game ON videos(game_id);
        CREATE INDEX IF NOT EXISTS idx_teams_project ON teams(project_id);
        CREATE INDEX IF NOT EXISTS idx_players_team ON players(team_id);
        CREATE INDEX IF NOT EXISTS idx_clips_game ON clips(game_id);
        CREATE INDEX IF NOT EXISTS idx_clip_players_clip ON clip_players(clip_id);
        CREATE INDEX IF NOT EXISTS idx_clip_players_player ON clip_players(player_id);

        -- Initial metadata
        INSERT OR IGNORE INTO app_metadata (key, value, updated_at)
        VALUES ('schema_version', '1.0.0', strftime('%s', 'now') * 1000);
        """
    }

    // MARK: - Recent Analysis Projects

    func getRecentProjects(limit: Int = 10) -> [AnalysisProject] {
        var projects: [AnalysisProject] = []

        let query = """
            SELECT project_id, name, modified_at, created_at
            FROM projects
            ORDER BY modified_at DESC
            LIMIT ?
        """

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(limit))

            while sqlite3_step(statement) == SQLITE_ROW {
                let projectId = String(cString: sqlite3_column_text(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let modifiedAt = sqlite3_column_int64(statement, 2)

                // Convert timestamp to Date
                let lastOpened = Date(timeIntervalSince1970: Double(modifiedAt) / 1000.0)

                // Calculate total duration from videos
                let duration = calculateProjectDuration(projectId: projectId)

                // Get thumbnail from first video
                let thumbnailPath = getFirstVideoThumbnail(projectId: projectId)

                let project = AnalysisProject(
                    id: projectId,
                    title: name,
                    lastOpened: lastOpened,
                    duration: duration,
                    thumbnailName: thumbnailPath
                )

                projects.append(project)
            }
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("Error preparing query: \(errorMessage)")
        }

        sqlite3_finalize(statement)
        return projects
    }

    func calculateProjectDuration(projectId: String) -> String {
        guard let db = db else { return "0h 0m" }

        // Get the max duration from videos (since multi-angle videos have the same duration)
        let query = """
            SELECT MAX(v.duration_ms) as max_duration
            FROM videos v
            JOIN games g ON v.game_id = g.game_id
            WHERE g.project_id = ?
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return "0h 0m"
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        projectId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) == SQLITE_ROW {
            let totalDurationMs = sqlite3_column_int64(statement, 0)

            // If no videos, return 0h 0m
            if totalDurationMs == 0 {
                return "0h 0m"
            }

            // Convert milliseconds to hours and minutes
            let totalSeconds = Int(totalDurationMs / 1000)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60

            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else if minutes > 0 {
                return "\(minutes)m"
            } else {
                return "0m"
            }
        }

        return "0h 0m"
    }

    func getFirstVideoThumbnail(projectId: String) -> String? {
        guard let db = db else { return nil }

        let query = """
            SELECT v.thumbnail_path
            FROM videos v
            JOIN games g ON v.game_id = g.game_id
            WHERE g.project_id = ?
            AND v.thumbnail_path IS NOT NULL
            ORDER BY v.import_date ASC
            LIMIT 1
        """

        var statement: OpaquePointer?
        var thumbnailPath: String?

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            projectId.withCString { cProjectId in
                sqlite3_bind_text(statement, 1, cProjectId, -1, SQLITE_TRANSIENT)
            }

            if sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    thumbnailPath = String(cString: cString)
                }
            }
        }

        sqlite3_finalize(statement)
        return thumbnailPath
    }

    func getProjectDetails(projectId: String) -> (name: String, sport: String, season: String?)? {
        guard let db = db else { return nil }

        let query = """
            SELECT name, sport, season
            FROM projects
            WHERE project_id = ?
        """

        var statement: OpaquePointer?
        var result: (String, String, String?)?

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            projectId.withCString { cProjectId in
                sqlite3_bind_text(statement, 1, cProjectId, -1, SQLITE_TRANSIENT)
            }

            if sqlite3_step(statement) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(statement, 0))
                let sport = String(cString: sqlite3_column_text(statement, 1))
                let season = sqlite3_column_text(statement, 2) != nil
                    ? String(cString: sqlite3_column_text(statement, 2))
                    : nil

                result = (name, sport, season)
            }
        }

        sqlite3_finalize(statement)
        return result
    }

    func getVideoCount(projectId: String) -> Int {
        var count = 0
        
        dbQueue.sync {
            guard let db = self.db else {
                print("❌ DatabaseManager.getVideoCount: No database connection")
                return
            }

            print("🔍 DatabaseManager.getVideoCount: Querying for project ID: \(projectId)")

            let query = """
                SELECT COUNT(*)
                FROM videos v
                JOIN games g ON v.game_id = g.game_id
                WHERE g.project_id = ?
            """

            var statement: OpaquePointer?

            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                projectId.withCString { cProjectId in
                    sqlite3_bind_text(statement, 1, cProjectId, -1, SQLITE_TRANSIENT)
                }

                if sqlite3_step(statement) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(statement, 0))
                }
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("❌ DatabaseManager.getVideoCount: Query preparation failed: \(errorMessage)")
            }

            sqlite3_finalize(statement)
            print("✅ DatabaseManager.getVideoCount: Returned count: \(count)")
        }
        
        return count
    }

    func getFirstGameId(projectId: String) -> String? {
        guard let db = db else { return nil }

        let query = """
            SELECT g.game_id
            FROM games g
            WHERE g.project_id = ?
            LIMIT 1
        """

        var statement: OpaquePointer?
        var gameId: String?

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            projectId.withCString { cProjectId in
                sqlite3_bind_text(statement, 1, cProjectId, -1, SQLITE_TRANSIENT)
            }

            if sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    gameId = String(cString: cString)
                }
            }
        }

        sqlite3_finalize(statement)
        return gameId
    }

    struct VideoInfo {
        let videoId: String
        let filePath: String
        let cameraAngle: String
        let durationMs: Int64
        let frameRate: Double
        let width: Int
        let height: Int
    }

    func getVideos(projectId: String) -> [VideoInfo] {
        var videos: [VideoInfo] = []
        
        dbQueue.sync {
            guard let db = self.db else {
                print("❌ DatabaseManager.getVideos: No database connection")
                return
            }

            print("🔍 DatabaseManager.getVideos: Querying for project ID: \(projectId)")

            let query = """
                SELECT v.video_id, v.file_path, v.camera_angle, v.duration_ms, v.frame_rate, v.resolution_width, v.resolution_height
                FROM videos v
                JOIN games g ON v.game_id = g.game_id
                WHERE g.project_id = ?
                ORDER BY v.import_date ASC
            """

            var statement: OpaquePointer?

            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                projectId.withCString { cProjectId in
                    sqlite3_bind_text(statement, 1, cProjectId, -1, SQLITE_TRANSIENT)
                }

                while sqlite3_step(statement) == SQLITE_ROW {
                    let videoId = String(cString: sqlite3_column_text(statement, 0))
                    let filePath = String(cString: sqlite3_column_text(statement, 1))
                    let cameraAngle = String(cString: sqlite3_column_text(statement, 2))
                    let durationMs = sqlite3_column_int64(statement, 3)
                    let frameRate = sqlite3_column_double(statement, 4)
                    let width = Int(sqlite3_column_int(statement, 5))
                    let height = Int(sqlite3_column_int(statement, 6))

                    videos.append(VideoInfo(
                        videoId: videoId,
                        filePath: filePath,
                        cameraAngle: cameraAngle,
                        durationMs: durationMs,
                        frameRate: frameRate,
                        width: width,
                        height: height
                    ))
                }
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("❌ DatabaseManager.getVideos: Query preparation failed: \(errorMessage)")
            }

            sqlite3_finalize(statement)
            print("✅ DatabaseManager.getVideos: Returned \(videos.count) videos")
        }
        
        return videos
    }

    // Check if project exists with given name and season
    func projectExists(name: String, season: String?) -> Bool {
        guard let db = db else { return false }

        let query = """
            SELECT COUNT(*) FROM projects
            WHERE name = ? AND season = ?
        """

        var statement: OpaquePointer?
        var exists = false

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, name, -1, nil)

            // Bind season as NULL if not provided, not empty string
            if let s = season {
                sqlite3_bind_text(statement, 2, s, -1, nil)
            } else {
                sqlite3_bind_null(statement, 2)
            }

            if sqlite3_step(statement) == SQLITE_ROW {
                let count = sqlite3_column_int(statement, 0)
                exists = count > 0
            }
        }

        sqlite3_finalize(statement)
        return exists
    }

    /// Updates the modified_at timestamp for a project (used by auto-save)
    func updateProjectModifiedDate(projectId: String) -> Result<Void, DatabaseError> {
        var result: Result<Void, DatabaseError>!
        
        dbQueue.sync {
            guard let db = self.db else {
                result = .failure(.noDatabase)
                return
            }

            let query = """
                UPDATE projects
                SET modified_at = ?
                WHERE project_id = ?
            """

            var statement: OpaquePointer?
            let currentTimestamp = Int64(Date().timeIntervalSince1970 * 1000) // milliseconds

            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int64(statement, 1, currentTimestamp)
                projectId.withCString { cProjectId in
                    sqlite3_bind_text(statement, 2, cProjectId, -1, SQLITE_TRANSIENT)
                }

                if sqlite3_step(statement) == SQLITE_DONE {
                    sqlite3_finalize(statement)
                    result = .success(())
                    return
                } else {
                    let errorMessage = String(cString: sqlite3_errmsg(db))
                    sqlite3_finalize(statement)
                    result = .failure(.executionFailed(errorMessage))
                    return
                }
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                result = .failure(.prepareFailed(errorMessage))
                return
            }
        }
        
        return result
    }

    // Begin transaction
    func beginTransaction() -> Bool {
        guard let db = db else {
            print("❌ BEGIN TRANSACTION failed: no database")
            return false
        }
        let result = sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) == SQLITE_OK
        if result {
            print("✅ BEGIN TRANSACTION successful")
        } else {
            print("❌ BEGIN TRANSACTION failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    // Commit transaction
    func commitTransaction() -> Bool {
        guard let db = db else {
            print("❌ COMMIT failed: no database")
            return false
        }
        let result = sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK
        if result {
            print("✅ COMMIT successful")
        } else {
            print("❌ COMMIT failed: \(String(cString: sqlite3_errmsg(db)))")
        }
        return result
    }

    // Rollback transaction
    func rollbackTransaction() {
        guard let db = db else {
            print("❌ ROLLBACK failed: no database")
            return
        }
        let result = sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
        if result == SQLITE_OK {
            print("✅ ROLLBACK successful")
        } else {
            print("❌ ROLLBACK failed: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    func createProject(name: String, sport: String, competition: String?) -> Result<String, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let projectId = UUID().uuidString
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        print("📁 Creating project with ID: \(projectId), name: \(name)")

        let insertSQL = """
            INSERT INTO projects (project_id, name, season, sport, created_at, modified_at)
            VALUES (?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            return .failure(.prepareFailed("createProject: \(errorMessage)"))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        projectId.withCString { cProjectId in
            sqlite3_bind_text(statement, 1, cProjectId, -1, SQLITE_TRANSIENT)
        }
        name.withCString { cName in
            sqlite3_bind_text(statement, 2, cName, -1, SQLITE_TRANSIENT)
        }

        // Bind season as NULL if not provided, not empty string
        if let comp = competition {
            comp.withCString { cComp in
                sqlite3_bind_text(statement, 3, cComp, -1, SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 3)
        }

        sport.withCString { cSport in
            sqlite3_bind_text(statement, 4, cSport, -1, SQLITE_TRANSIENT)
        }
        sqlite3_bind_int64(statement, 5, timestamp)
        sqlite3_bind_int64(statement, 6, timestamp)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(statement)
            return .failure(.executionFailed("createProject: \(errorMessage)"))
        }

        print("✅ Successfully created project: \(name) with ID: \(projectId)")
        sqlite3_finalize(statement)
        return .success(projectId)
    }

    func createGame(projectId: String, name: String) -> Result<String, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let gameId = UUID().uuidString
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        print("🏀 Creating game with ID: \(gameId) for project: \(projectId)")

        let insertSQL = """
            INSERT INTO games (game_id, project_id, game_date, created_at, modified_at, game_type)
            VALUES (?, ?, ?, ?, ?, 'regular_season')
        """

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            return .failure(.prepareFailed("createGame: \(errorMessage)"))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        gameId.withCString { cGameId in
            sqlite3_bind_text(statement, 1, cGameId, -1, SQLITE_TRANSIENT)
        }
        projectId.withCString { cProjectId in
            sqlite3_bind_text(statement, 2, cProjectId, -1, SQLITE_TRANSIENT)
        }
        sqlite3_bind_int64(statement, 3, timestamp)
        sqlite3_bind_int64(statement, 4, timestamp)
        sqlite3_bind_int64(statement, 5, timestamp)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(statement)
            return .failure(.executionFailed("createGame: \(errorMessage)"))
        }

        print("✅ Successfully created game with ID: \(gameId)")
        sqlite3_finalize(statement)
        return .success(gameId)
    }

    func saveVideo(gameId: String, filePath: String, cameraAngle: String, durationMs: Int64, frameRate: Double, width: Int, height: Int, codec: String, thumbnailPath: String?) -> Result<String, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let videoId = UUID().uuidString
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        print("🎬 Attempting to save video with ID: \(videoId) for file: \(filePath)")

        let insertSQL = """
            INSERT INTO videos (
                video_id, game_id, file_path, camera_angle, duration_ms,
                frame_rate, resolution_width, resolution_height, codec,
                import_date, thumbnail_path
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            return .failure(.prepareFailed("saveVideo: \(errorMessage)"))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        videoId.withCString { cVideoId in
            sqlite3_bind_text(statement, 1, cVideoId, -1, SQLITE_TRANSIENT)
        }
        gameId.withCString { cGameId in
            sqlite3_bind_text(statement, 2, cGameId, -1, SQLITE_TRANSIENT)
        }
        filePath.withCString { cFilePath in
            sqlite3_bind_text(statement, 3, cFilePath, -1, SQLITE_TRANSIENT)
        }
        cameraAngle.withCString { cCameraAngle in
            sqlite3_bind_text(statement, 4, cCameraAngle, -1, SQLITE_TRANSIENT)
        }
        sqlite3_bind_int64(statement, 5, durationMs)
        sqlite3_bind_double(statement, 6, frameRate)
        sqlite3_bind_int(statement, 7, Int32(width))
        sqlite3_bind_int(statement, 8, Int32(height))
        codec.withCString { cCodec in
            sqlite3_bind_text(statement, 9, cCodec, -1, SQLITE_TRANSIENT)
        }
        sqlite3_bind_int64(statement, 10, timestamp)

        if let thumb = thumbnailPath {
            thumb.withCString { cThumb in
                sqlite3_bind_text(statement, 11, cThumb, -1, SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 11)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(statement)
            print("❌ Failed to save video \(videoId): \(errorMessage)")
            return .failure(.executionFailed("saveVideo: \(errorMessage)"))
        }

        print("✅ Successfully saved video: \(videoId)")
        sqlite3_finalize(statement)
        return .success(videoId)
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    // MARK: - Clips Management

    /// Create a new clip
    func createClip(
        gameId: String,
        startTimeMs: Int64,
        endTimeMs: Int64,
        title: String,
        notes: String = "",
        tags: [String] = []
    ) -> Result<Clip, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let clipId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let tagsJson = (try? JSONSerialization.data(withJSONObject: tags))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        let query = """
            INSERT INTO clips (
                clip_id, game_id, start_time_ms, end_time_ms,
                title, notes, tags, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.createClip: Failed to prepare statement: \(error)")
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        clipId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        gameId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 3, startTimeMs)
        sqlite3_bind_int64(statement, 4, endTimeMs)
        title.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }
        notes.withCString { sqlite3_bind_text(statement, 6, $0, -1, SQLITE_TRANSIENT) }
        tagsJson.withCString { sqlite3_bind_text(statement, 7, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 8, now)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.createClip: Failed to insert: \(error)")
            return .failure(.executionFailed(error))
        }

        let clip = Clip(
            id: clipId,
            gameId: gameId,
            startTimeMs: startTimeMs,
            endTimeMs: endTimeMs,
            title: title,
            notes: notes,
            tags: tags,
            createdAt: Date(timeIntervalSince1970: TimeInterval(now) / 1000)
        )

        // Auto-link players from overlapping moments
        let playerIds = getPlayerIdsForTimeRange(gameId: gameId, startTimeMs: startTimeMs, endTimeMs: endTimeMs)
        if !playerIds.isEmpty {
            _ = addPlayersToClip(clipId: clipId, playerIds: playerIds)
            print("✅ DatabaseManager.createClip: Auto-linked \(playerIds.count) player(s) to clip")
        }

        print("✅ DatabaseManager.createClip: Created clip '\(title)' (\(clip.formattedDuration))")
        return .success(clip)
    }

    /// Get all clips for a game
    func getClips(gameId: String) -> [Clip] {
        guard let db = db else {
            print("❌ DatabaseManager.getClips: No database connection")
            return []
        }

        let query = """
            SELECT clip_id, game_id, start_time_ms, end_time_ms,
                   title, notes, tags, created_at, modified_at
            FROM clips
            WHERE game_id = ?
            ORDER BY start_time_ms ASC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getClips: Failed to prepare: \(error)")
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        gameId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var clips: [Clip] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let clipId = String(cString: sqlite3_column_text(statement, 0))
            let gameId = String(cString: sqlite3_column_text(statement, 1))
            let startTimeMs = sqlite3_column_int64(statement, 2)
            let endTimeMs = sqlite3_column_int64(statement, 3)
            let title = String(cString: sqlite3_column_text(statement, 4))
            let notes = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 5))
                : ""
            let tagsJson = sqlite3_column_type(statement, 6) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 6))
                : "[]"
            let createdAt = sqlite3_column_int64(statement, 7)
            let modifiedAt = sqlite3_column_type(statement, 8) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 8)
                : nil

            let tags = (try? JSONSerialization.jsonObject(
                with: Data(tagsJson.utf8),
                options: []
            ) as? [String]) ?? []

            let clip = Clip(
                id: clipId,
                gameId: gameId,
                startTimeMs: startTimeMs,
                endTimeMs: endTimeMs,
                title: title,
                notes: notes,
                tags: tags,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000),
                modifiedAt: modifiedAt.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
            )

            clips.append(clip)
        }

        print("✅ DatabaseManager.getClips: Found \(clips.count) clips for game \(gameId)")
        return clips
    }

    /// Delete a clip
    func deleteClip(clipId: String) -> Result<Void, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let query = "DELETE FROM clips WHERE clip_id = ?"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.deleteClip: Failed to prepare: \(error)")
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        clipId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.deleteClip: Failed to delete: \(error)")
            return .failure(.executionFailed(error))
        }

        print("✅ DatabaseManager.deleteClip: Deleted clip \(clipId)")
        return .success(())
    }

    // MARK: - Clip-Player Relationships

    /// Link a player to a clip
    func addPlayerToClip(clipId: String, playerId: String) -> Result<Void, DatabaseError> {
        guard let db = db else { return .failure(.noDatabase) }

        let query = """
            INSERT OR IGNORE INTO clip_players (clip_id, player_id, created_at)
            VALUES (?, ?, ?)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        clipId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        playerId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 3, now)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(.executionFailed(error))
        }

        return .success(())
    }

    /// Link multiple players to a clip
    func addPlayersToClip(clipId: String, playerIds: [String]) -> Result<Void, DatabaseError> {
        for playerId in playerIds {
            if case .failure(let error) = addPlayerToClip(clipId: clipId, playerId: playerId) {
                return .failure(error)
            }
        }
        return .success(())
    }

    /// Remove a player from a clip
    func removePlayerFromClip(clipId: String, playerId: String) -> Result<Void, DatabaseError> {
        guard let db = db else { return .failure(.noDatabase) }

        let query = "DELETE FROM clip_players WHERE clip_id = ? AND player_id = ?"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        clipId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        playerId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(.executionFailed(error))
        }

        return .success(())
    }

    /// Get all player IDs associated with a clip
    func getPlayerIdsForClip(clipId: String) -> [String] {
        guard let db = db else { return [] }

        let query = "SELECT player_id FROM clip_players WHERE clip_id = ?"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        clipId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var playerIds: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let playerIdPtr = sqlite3_column_text(statement, 0) {
                playerIds.append(String(cString: playerIdPtr))
            }
        }

        return playerIds
    }

    /// Get all clips for a specific player
    func getClipsForPlayer(playerId: String) -> [Clip] {
        guard let db = db else { return [] }

        let query = """
            SELECT c.clip_id, c.game_id, c.start_time_ms, c.end_time_ms, c.title,
                   c.notes, c.tags, c.thumbnail_path, c.created_at, c.modified_at
            FROM clips c
            INNER JOIN clip_players cp ON c.clip_id = cp.clip_id
            WHERE cp.player_id = ?
            ORDER BY c.created_at DESC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        playerId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var clips: [Clip] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let clipId = String(cString: sqlite3_column_text(statement, 0))
            let gameId = String(cString: sqlite3_column_text(statement, 1))
            let startTimeMs = sqlite3_column_int64(statement, 2)
            let endTimeMs = sqlite3_column_int64(statement, 3)
            let title = String(cString: sqlite3_column_text(statement, 4))

            let notes = sqlite3_column_type(statement, 5) != SQLITE_NULL ?
                String(cString: sqlite3_column_text(statement, 5)) : ""

            let tagsJson = sqlite3_column_type(statement, 6) != SQLITE_NULL ?
                String(cString: sqlite3_column_text(statement, 6)) : "[]"
            let tags = (try? JSONDecoder().decode([String].self, from: tagsJson.data(using: .utf8) ?? Data())) ?? []

            let thumbnailPath = sqlite3_column_type(statement, 7) != SQLITE_NULL ?
                String(cString: sqlite3_column_text(statement, 7)) : nil

            let createdAtMs = sqlite3_column_int64(statement, 8)
            let createdAt = Date(timeIntervalSince1970: Double(createdAtMs) / 1000.0)

            let modifiedAtMs = sqlite3_column_int64(statement, 9)
            let modifiedAt = modifiedAtMs > 0 ? Date(timeIntervalSince1970: Double(modifiedAtMs) / 1000.0) : nil

            let clip = Clip(
                id: clipId,
                gameId: gameId,
                startTimeMs: startTimeMs,
                endTimeMs: endTimeMs,
                title: title,
                notes: notes,
                tags: tags,
                thumbnailPath: thumbnailPath,
                createdAt: createdAt,
                modifiedAt: modifiedAt
            )
            clips.append(clip)
        }

        return clips
    }

    /// Get all player IDs associated with moments that overlap a given time range
    private func getPlayerIdsForTimeRange(gameId: String, startTimeMs: Int64, endTimeMs: Int64) -> [String] {
        guard let db = db else {
            print("❌ DatabaseManager.getPlayerIdsForTimeRange: No database connection")
            return []
        }

        let query = """
            SELECT DISTINCT mp.player_id
            FROM moment_players mp
            JOIN moments m ON mp.moment_id = m.moment_id
            WHERE m.game_id = ?
            AND m.start_time_ms < ?
            AND m.end_time_ms > ?
            ORDER BY mp.player_id
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getPlayerIdsForTimeRange: Failed to prepare statement: \(error)")
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        gameId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 2, endTimeMs)
        sqlite3_bind_int64(statement, 3, startTimeMs)

        var playerIds: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                let playerId = String(cString: cString)
                playerIds.append(playerId)
            }
        }

        return playerIds
    }

    // MARK: - Playlists Management

    /// Create a new playlist
    func createPlaylist(
        projectId: String,
        name: String,
        purpose: PlaylistPurpose,
        description: String? = nil,
        filterCriteria: PlaylistFilters? = nil,
        clipIds: [String] = []
    ) -> Result<Playlist, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let playlistId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        // Serialize filter criteria and clip IDs to JSON
        let filterJson = filterCriteria.flatMap { filters in
            try? JSONEncoder().encode(filters)
        }.flatMap { String(data: $0, encoding: .utf8) }

        let clipIdsJson = (try? JSONSerialization.data(withJSONObject: clipIds))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        let query = """
            INSERT INTO playlists (
                playlist_id, project_id, name, purpose, description,
                filter_criteria, clip_ids, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.createPlaylist: Failed to prepare: \(error)")
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        playlistId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        projectId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        name.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        purpose.rawValue.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }

        if let desc = description {
            desc.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 5)
        }

        if let filterJson = filterJson {
            filterJson.withCString { sqlite3_bind_text(statement, 6, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 6)
        }

        clipIdsJson.withCString { sqlite3_bind_text(statement, 7, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 8, now)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.createPlaylist: Failed to insert: \(error)")
            return .failure(.executionFailed(error))
        }

        let playlist = Playlist(
            id: playlistId,
            projectId: projectId,
            name: name,
            purpose: purpose,
            description: description,
            filterCriteria: filterCriteria,
            clipIds: clipIds,
            createdAt: Date(timeIntervalSince1970: TimeInterval(now) / 1000)
        )

        print("✅ DatabaseManager.createPlaylist: Created playlist '\(name)'")
        return .success(playlist)
    }

    /// Get all playlists for a project
    func getPlaylists(projectId: String) -> [Playlist] {
        guard let db = db else {
            print("❌ DatabaseManager.getPlaylists: No database connection")
            return []
        }

        let query = """
            SELECT playlist_id, project_id, name, purpose, description,
                   filter_criteria, clip_ids, created_at, modified_at
            FROM playlists
            WHERE project_id = ?
            ORDER BY created_at DESC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getPlaylists: Failed to prepare: \(error)")
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        projectId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var playlists: [Playlist] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let playlistId = String(cString: sqlite3_column_text(statement, 0))
            let projId = String(cString: sqlite3_column_text(statement, 1))
            let name = String(cString: sqlite3_column_text(statement, 2))
            let purposeStr = String(cString: sqlite3_column_text(statement, 3))
            let description = sqlite3_column_type(statement, 4) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 4))
                : nil
            let filterJson = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 5))
                : nil
            let clipIdsJson = String(cString: sqlite3_column_text(statement, 6))
            let createdAt = sqlite3_column_int64(statement, 7)
            let modifiedAt = sqlite3_column_type(statement, 8) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 8)
                : nil

            let purpose = PlaylistPurpose(rawValue: purposeStr) ?? .teaching

            let filterCriteria = filterJson.flatMap { json in
                try? JSONDecoder().decode(PlaylistFilters.self, from: Data(json.utf8))
            }

            let clipIds = (try? JSONSerialization.jsonObject(
                with: Data(clipIdsJson.utf8),
                options: []
            ) as? [String]) ?? []

            let playlist = Playlist(
                id: playlistId,
                projectId: projId,
                name: name,
                purpose: purpose,
                description: description,
                filterCriteria: filterCriteria,
                clipIds: clipIds,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000),
                modifiedAt: modifiedAt.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
            )

            playlists.append(playlist)
        }

        print("✅ DatabaseManager.getPlaylists: Found \(playlists.count) playlists")
        return playlists
    }

    /// Update a playlist
    func updatePlaylist(_ playlist: Playlist) -> Result<Void, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)

        let filterJson = playlist.filterCriteria.flatMap { filters in
            try? JSONEncoder().encode(filters)
        }.flatMap { String(data: $0, encoding: .utf8) }

        let clipIdsJson = (try? JSONSerialization.data(withJSONObject: playlist.clipIds))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        let query = """
            UPDATE playlists
            SET name = ?, purpose = ?, description = ?,
                filter_criteria = ?, clip_ids = ?, modified_at = ?
            WHERE playlist_id = ?
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.updatePlaylist: Failed to prepare: \(error)")
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        playlist.name.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        playlist.purpose.rawValue.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }

        if let desc = playlist.description {
            desc.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 3)
        }

        if let filterJson = filterJson {
            filterJson.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 4)
        }

        clipIdsJson.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 6, now)
        playlist.id.withCString { sqlite3_bind_text(statement, 7, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.updatePlaylist: Failed to update: \(error)")
            return .failure(.executionFailed(error))
        }

        print("✅ DatabaseManager.updatePlaylist: Updated playlist '\(playlist.name)'")
        return .success(())
    }

    /// Delete a playlist
    func deletePlaylist(playlistId: String) -> Result<Void, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let query = "DELETE FROM playlists WHERE playlist_id = ?"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.deletePlaylist: Failed to prepare: \(error)")
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        playlistId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.deletePlaylist: Failed to delete: \(error)")
            return .failure(.executionFailed(error))
        }

        print("✅ DatabaseManager.deletePlaylist: Deleted playlist \(playlistId)")
        return .success(())
    }

    /// Get clips with enriched metadata for playlist display
    func getClipsWithMetadata(clipIds: [String]) -> [PlaylistClipWithMetadata] {
        guard let db = db else {
            print("❌ DatabaseManager.getClipsWithMetadata: No database connection")
            return []
        }

        var enrichedClips: [PlaylistClipWithMetadata] = []

        for clipId in clipIds {
            // Get the clip
            let clipQuery = """
                SELECT clip_id, game_id, start_time_ms, end_time_ms,
                       title, notes, tags, created_at, modified_at
                FROM clips
                WHERE clip_id = ?
            """

            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, clipQuery, -1, &statement, nil) != SQLITE_OK {
                continue
            }

            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            clipId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                sqlite3_finalize(statement)
                continue
            }

            let cId = String(cString: sqlite3_column_text(statement, 0))
            let gId = String(cString: sqlite3_column_text(statement, 1))
            let startMs = sqlite3_column_int64(statement, 2)
            let endMs = sqlite3_column_int64(statement, 3)
            let title = String(cString: sqlite3_column_text(statement, 4))
            let notes = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 5))
                : ""
            let tagsJson = sqlite3_column_type(statement, 6) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 6))
                : "[]"
            let createdAt = sqlite3_column_int64(statement, 7)
            let modifiedAt = sqlite3_column_type(statement, 8) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 8)
                : nil

            let tags = (try? JSONSerialization.jsonObject(
                with: Data(tagsJson.utf8),
                options: []
            ) as? [String]) ?? []

            let clip = Clip(
                id: cId,
                gameId: gId,
                startTimeMs: startMs,
                endTimeMs: endMs,
                title: title,
                notes: notes,
                tags: tags,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000),
                modifiedAt: modifiedAt.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
            )

            sqlite3_finalize(statement)

            // Find moment that overlaps with this clip
            let moment = findMomentForClip(gameId: gId, startMs: startMs, endMs: endMs)

            // Get layers within this clip's time range
            let layers = getLayersForTimeRange(gameId: gId, startMs: startMs, endMs: endMs)

            // Extract metadata from layers
            let outcome = layers.first { ["Made", "Missed", "Turnover"].contains($0.layerType) }?.layerType

            // Get quarter from moment or estimate from timestamp
            let quarter = estimateQuarter(timestampMs: startMs)

            // Get players for this moment
            let players = moment != nil ? getPlayersForMoment(momentId: moment!.id) : []

            let enrichedClip = PlaylistClipWithMetadata(
                clip: clip,
                moment: moment,
                layers: layers,
                players: players,
                outcome: outcome,
                quarter: quarter,
                setName: nil // TODO: Extract set name from tags if available
            )

            enrichedClips.append(enrichedClip)
        }

        return enrichedClips
    }

    /// Find moment that contains the given time range
    private func findMomentForClip(gameId: String, startMs: Int64, endMs: Int64) -> Moment? {
        guard let db = db else { return nil }

        let query = """
            SELECT tag_id, game_id, tag_category, start_timestamp_ms, end_timestamp_ms,
                   duration_ms, notes, created_at, modified_at
            FROM tags
            WHERE game_id = ?
              AND start_timestamp_ms <= ?
              AND (end_timestamp_ms >= ? OR end_timestamp_ms IS NULL)
            LIMIT 1
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            return nil
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        gameId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 2, startMs)
        sqlite3_bind_int64(statement, 3, endMs)

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

        let id = String(cString: sqlite3_column_text(statement, 0))
        let gId = String(cString: sqlite3_column_text(statement, 1))
        let category = String(cString: sqlite3_column_text(statement, 2))
        let startTimestamp = sqlite3_column_int64(statement, 3)
        let endTimestamp = sqlite3_column_type(statement, 4) != SQLITE_NULL
            ? sqlite3_column_int64(statement, 4)
            : nil
        let durationMs = sqlite3_column_type(statement, 5) != SQLITE_NULL
            ? sqlite3_column_int64(statement, 5)
            : nil
        let notes = sqlite3_column_type(statement, 6) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 6))
            : nil
        let createdAt = sqlite3_column_int64(statement, 7)
        let modifiedAt = sqlite3_column_type(statement, 8) != SQLITE_NULL
            ? sqlite3_column_int64(statement, 8)
            : nil

        return Moment(
            id: id,
            gameId: gId,
            momentCategory: category,
            startTimestampMs: startTimestamp,
            endTimestampMs: endTimestamp,
            durationMs: durationMs,
            notes: notes,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000),
            modifiedAt: modifiedAt.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        )
    }

    /// Get layers within a time range
    private func getLayersForTimeRange(gameId: String, startMs: Int64, endMs: Int64) -> [Layer] {
        guard let db = db else { return [] }

        // Get all moments that overlap with this time range
        let momentQuery = """
            SELECT tag_id FROM tags
            WHERE game_id = ?
              AND start_timestamp_ms <= ?
              AND (end_timestamp_ms >= ? OR end_timestamp_ms IS NULL)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, momentQuery, -1, &statement, nil) != SQLITE_OK {
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        gameId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 2, endMs)
        sqlite3_bind_int64(statement, 3, startMs)

        var momentIds: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let momentId = String(cString: sqlite3_column_text(statement, 0))
            momentIds.append(momentId)
        }

        // Get layers for these moments
        var allLayers: [Layer] = []
        for momentId in momentIds {
            allLayers.append(contentsOf: getLayers(momentId: momentId))
        }

        return allLayers
    }

    /// Check if a moment has any of the specified players
    func momentHasPlayers(momentId: String, playerIds: [String]) -> Bool {
        guard let db = db else { return false }
        guard !playerIds.isEmpty else { return true }

        let placeholders = playerIds.map { _ in "?" }.joined(separator: ", ")
        let query = """
            SELECT COUNT(*) FROM moment_players
            WHERE moment_id = ? AND player_id IN (\(placeholders))
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            return false
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        momentId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        for (index, playerId) in playerIds.enumerated() {
            playerId.withCString { sqlite3_bind_text(statement, Int32(index + 2), $0, -1, SQLITE_TRANSIENT) }
        }

        if sqlite3_step(statement) == SQLITE_ROW {
            let count = sqlite3_column_int(statement, 0)
            return count > 0
        }

        return false
    }

    /// Get all players for a project (from all teams in the project)
    func getPlayersForProject(projectId: String) -> [Player] {
        guard let db = db else { return [] }

        let query = """
            SELECT p.player_id, p.team_id, p.first_name, p.last_name, p.jersey_number,
                   p.position, p.height_inches, p.weight_lbs, p.class_year,
                   p.birth_date, p.notes, p.is_active
            FROM players p
            INNER JOIN teams t ON p.team_id = t.team_id
            WHERE t.project_id = ? AND p.is_active = 1
            ORDER BY p.jersey_number
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        projectId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var players: [Player] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let playerId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))) ?? UUID()
            let firstName = String(cString: sqlite3_column_text(statement, 2))
            let lastName = String(cString: sqlite3_column_text(statement, 3))
            let jerseyNumber = Int(sqlite3_column_int(statement, 4))
            let position = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 5))
                : ""
            let notes = sqlite3_column_type(statement, 10) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 10))
                : ""

            let player = Player(
                id: playerId,
                name: "\(firstName) \(lastName)",
                number: jerseyNumber,
                position: position,
                notes: notes
            )

            players.append(player)
        }

        return players
    }

    /// Get players associated with a moment
    func getPlayersForMoment(momentId: String) -> [Player] {
        guard let db = db else { return [] }

        let query = """
            SELECT p.player_id, p.team_id, p.first_name, p.last_name, p.jersey_number,
                   p.position, p.height_inches, p.weight_lbs, p.class_year,
                   p.birth_date, p.notes, p.is_active
            FROM players p
            INNER JOIN moment_players mp ON p.player_id = mp.player_id
            WHERE mp.moment_id = ?
            ORDER BY p.jersey_number
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        momentId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var players: [Player] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let playerId = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))) ?? UUID()
            let firstName = String(cString: sqlite3_column_text(statement, 2))
            let lastName = String(cString: sqlite3_column_text(statement, 3))
            let jerseyNumber = Int(sqlite3_column_int(statement, 4))
            let position = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 5))
                : ""
            let notes = sqlite3_column_type(statement, 10) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 10))
                : ""

            let player = Player(
                id: playerId,
                name: "\(firstName) \(lastName)",
                number: jerseyNumber,
                position: position,
                notes: notes
            )

            players.append(player)
        }

        return players
    }

    /// Attach players to a moment
    func attachPlayersToMoment(momentId: String, playerIds: [String]) -> Result<Void, DatabaseError> {
        guard let db = db else { return .failure(.noDatabase) }
        guard !playerIds.isEmpty else { return .success(()) }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        // First, remove existing player associations for this moment
        let deleteQuery = "DELETE FROM moment_players WHERE moment_id = ?"
        var deleteStmt: OpaquePointer?
        defer { sqlite3_finalize(deleteStmt) }

        if sqlite3_prepare_v2(db, deleteQuery, -1, &deleteStmt, nil) == SQLITE_OK {
            momentId.withCString { sqlite3_bind_text(deleteStmt, 1, $0, -1, SQLITE_TRANSIENT) }
            sqlite3_step(deleteStmt)
        }

        // Insert new player associations
        let insertQuery = """
        INSERT INTO moment_players (moment_id, player_id, created_at)
        VALUES (?, ?, ?)
        """

        for playerId in playerIds {
            var insertStmt: OpaquePointer?
            defer { sqlite3_finalize(insertStmt) }

            if sqlite3_prepare_v2(db, insertQuery, -1, &insertStmt, nil) == SQLITE_OK {
                momentId.withCString { sqlite3_bind_text(insertStmt, 1, $0, -1, SQLITE_TRANSIENT) }
                playerId.withCString { sqlite3_bind_text(insertStmt, 2, $0, -1, SQLITE_TRANSIENT) }
                sqlite3_bind_int64(insertStmt, 3, now)

                if sqlite3_step(insertStmt) != SQLITE_DONE {
                    let errorMessage = String(cString: sqlite3_errmsg(db))
                    print("❌ Failed to attach player \(playerId) to moment: \(errorMessage)")
                    return .failure(.insertFailed)
                }
            }
        }

        print("✅ Attached \(playerIds.count) player(s) to moment \(momentId)")
        return .success(())
    }

    /// Detach all players from a moment
    func detachPlayersFromMoment(momentId: String) -> Result<Void, DatabaseError> {
        guard let db = db else { return .failure(.noDatabase) }

        let query = "DELETE FROM moment_players WHERE moment_id = ?"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            return .failure(.deleteFailed)
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        momentId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) == SQLITE_DONE {
            return .success(())
        } else {
            return .failure(.deleteFailed)
        }
    }

    /// Estimate quarter from timestamp (assumes 12-minute quarters, 48-minute game)
    func estimateQuarter(timestampMs: Int64) -> Int {
        let seconds = timestampMs / 1000
        let minutes = seconds / 60
        let quarterLength: Int64 = 12 // minutes

        if minutes < quarterLength {
            return 1
        } else if minutes < quarterLength * 2 {
            return 2
        } else if minutes < quarterLength * 3 {
            return 3
        } else {
            return 4
        }
    }

    // MARK: - Moments Management (Time-based events, formerly Tags)

    /// Start a new moment - activates a moment category and begins recording
    func startMoment(gameId: String, category: String, timestampMs: Int64) -> Result<Moment, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        print("📍 DatabaseManager.startMoment: Using database at \(dbPath)")

        let momentId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        let query = """
            INSERT INTO tags (
                tag_id, game_id, tag_category, start_timestamp_ms, created_at
            ) VALUES (?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.startMoment: Failed to prepare: \(error)")
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        momentId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        gameId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        category.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 4, timestampMs)
        sqlite3_bind_int64(statement, 5, now)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.startMoment: Failed to insert: \(error)")
            return .failure(.executionFailed(error))
        }

        let moment = Moment(
            id: momentId,
            gameId: gameId,
            momentCategory: category,
            startTimestampMs: timestampMs,
            createdAt: Date(timeIntervalSince1970: TimeInterval(now) / 1000.0)
        )

        print("✅ DatabaseManager.startMoment: Started '\(category)' moment at \(timestampMs)ms")
        return .success(moment)
    }

    /// Update moment times (start and end timestamps)
    func updateMomentTimes(momentId: String, startTimeMs: Int64, endTimeMs: Int64) -> Result<Void, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let durationMs = endTimeMs - startTimeMs
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let query = """
            UPDATE tags
            SET start_timestamp_ms = ?, end_timestamp_ms = ?, duration_ms = ?, modified_at = ?
            WHERE tag_id = ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare update moment times statement")
            return .failure(.executionFailed("Failed to prepare statement"))
        }
        defer { sqlite3_finalize(statement) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        sqlite3_bind_int64(statement, 1, startTimeMs)
        sqlite3_bind_int64(statement, 2, endTimeMs)
        sqlite3_bind_int64(statement, 3, durationMs)
        sqlite3_bind_int64(statement, 4, now)
        momentId.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            print("❌ Failed to update moment times")
            return .failure(.executionFailed("Failed to execute update"))
        }

        print("✅ Updated moment times: \(startTimeMs)ms - \(endTimeMs)ms (duration: \(durationMs)ms)")
        return .success(())
    }

    /// Update notes for a moment
    func updateMomentNotes(momentId: String, notes: String?) -> Result<Void, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let query = """
            UPDATE tags
            SET notes = ?, modified_at = ?
            WHERE tag_id = ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare update notes statement")
            return .failure(.executionFailed("Failed to prepare statement"))
        }
        defer { sqlite3_finalize(statement) }

        // Bind parameters
        if let notes = notes {
            notes.withCString { sqlite3_bind_text(statement, 1, $0, -1, nil) }
        } else {
            sqlite3_bind_null(statement, 1)
        }
        sqlite3_bind_int64(statement, 2, now)
        momentId.withCString { sqlite3_bind_text(statement, 3, $0, -1, nil) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            print("❌ Failed to update moment notes")
            return .failure(.executionFailed("Failed to update notes"))
        }

        print("✅ Updated notes for moment \(momentId)")
        return .success(())
    }

    /// Update clip duration by changing the end time
    func updateClipDuration(clipId: String, endTimeMs: Int64) -> Result<Void, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let query = """
            UPDATE clips
            SET end_time_ms = ?, modified_at = ?
            WHERE clip_id = ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare update clip duration statement")
            return .failure(.executionFailed("Failed to prepare statement"))
        }
        defer { sqlite3_finalize(statement) }

        // Bind parameters
        sqlite3_bind_int64(statement, 1, endTimeMs)
        sqlite3_bind_int64(statement, 2, now)
        clipId.withCString { sqlite3_bind_text(statement, 3, $0, -1, nil) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            print("❌ Failed to update clip duration")
            return .failure(.executionFailed("Failed to update clip duration"))
        }

        print("✅ Updated clip duration for clip \(clipId) - new end time: \(endTimeMs)ms")
        return .success(())
    }

    /// Update clip times by changing both start and end times
    func updateClipTimes(clipId: String, startTimeMs: Int64, endTimeMs: Int64) -> Result<Void, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let query = """
            UPDATE clips
            SET start_time_ms = ?, end_time_ms = ?, modified_at = ?
            WHERE clip_id = ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare update clip times statement")
            return .failure(.executionFailed("Failed to prepare statement"))
        }
        defer { sqlite3_finalize(statement) }

        // Bind parameters
        sqlite3_bind_int64(statement, 1, startTimeMs)
        sqlite3_bind_int64(statement, 2, endTimeMs)
        sqlite3_bind_int64(statement, 3, now)
        clipId.withCString { sqlite3_bind_text(statement, 4, $0, -1, nil) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            print("❌ Failed to update clip times")
            return .failure(.executionFailed("Failed to update clip times"))
        }

        print("✅ Updated clip times for clip \(clipId) - start: \(startTimeMs)ms, end: \(endTimeMs)ms")
        return .success(())
    }

    /// End an active tag - stops recording and calculates duration
    func endMoment(momentId: String, endTimestampMs: Int64) -> Result<Moment, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        // First, get the tag to calculate duration
        guard let moment = getMoment(momentId: momentId) else {
            return .failure(.executionFailed("Tag not found"))
        }

        let durationMs = endTimestampMs - moment.startTimestampMs
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        let query = """
            UPDATE tags
            SET end_timestamp_ms = ?, duration_ms = ?, modified_at = ?
            WHERE tag_id = ?
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.endTag: Failed to prepare: \(error)")
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        sqlite3_bind_int64(statement, 1, endTimestampMs)
        sqlite3_bind_int64(statement, 2, durationMs)
        sqlite3_bind_int64(statement, 3, now)
        momentId.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.endTag: Failed to update: \(error)")
            return .failure(.executionFailed(error))
        }

        var updatedMoment = moment
        updatedMoment.endTimestampMs = endTimestampMs
        updatedMoment.durationMs = durationMs
        updatedMoment.modifiedAt = Date(timeIntervalSince1970: TimeInterval(now) / 1000.0)

        print("✅ DatabaseManager.endMoment: Ended '\(moment.momentCategory)' moment (duration: \(durationMs)ms)")
        return .success(updatedMoment)
    }

    /// Get a specific tag by ID
    func getMoment(momentId: String) -> Moment? {
        guard let db = db else {
            print("❌ DatabaseManager.getTag: No database connection")
            return nil
        }

        let query = """
            SELECT tag_id, game_id, tag_category, start_timestamp_ms, end_timestamp_ms,
                   duration_ms, notes, created_at, modified_at
            FROM tags
            WHERE tag_id = ?
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getTag: Failed to prepare: \(error)")
            return nil
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        momentId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let gameId = String(cString: sqlite3_column_text(statement, 1))
            let category = String(cString: sqlite3_column_text(statement, 2))
            let startMs = sqlite3_column_int64(statement, 3)
            let endMs = sqlite3_column_type(statement, 4) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 4)
                : nil
            let durationMs = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 5)
                : nil
            let notes = sqlite3_column_type(statement, 6) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 6))
                : nil
            let createdAt = sqlite3_column_int64(statement, 7)
            let modifiedAt = sqlite3_column_type(statement, 8) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 8)
                : nil

            return Moment(
                id: id,
                gameId: gameId,
                momentCategory: category,
                startTimestampMs: startMs,
                endTimestampMs: endMs,
                durationMs: durationMs,
                notes: notes,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000.0),
                modifiedAt: modifiedAt != nil ? Date(timeIntervalSince1970: TimeInterval(modifiedAt!) / 1000.0) : nil
            )
        }

        return nil
    }

    /// Get all moments for a project (across all games)
    func getMomentsForProject(projectId: String) -> [Moment] {
        guard let db = db else {
            print("❌ DatabaseManager.getMomentsForProject: No database connection")
            return []
        }

        print("📍 DatabaseManager.getMomentsForProject: Using database at \(dbPath)")
        print("   🔍 Querying for projectId: \(projectId)")

        let query = """
            SELECT t.tag_id, t.game_id, t.tag_category, t.start_timestamp_ms, t.end_timestamp_ms,
                   t.duration_ms, t.notes, t.created_at, t.modified_at
            FROM tags t
            INNER JOIN games g ON t.game_id = g.game_id
            WHERE g.project_id = ?
            ORDER BY t.start_timestamp_ms ASC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getMomentsForProject: Failed to prepare: \(error)")
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        projectId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var moments: [Moment] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let gId = String(cString: sqlite3_column_text(statement, 1))
            let category = String(cString: sqlite3_column_text(statement, 2))
            let startMs = sqlite3_column_int64(statement, 3)
            let endMs = sqlite3_column_type(statement, 4) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 4)
                : nil
            let durationMs = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 5)
                : nil
            let notes = sqlite3_column_type(statement, 6) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 6))
                : nil
            let createdAt = sqlite3_column_int64(statement, 7)
            let modifiedAt = sqlite3_column_type(statement, 8) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 8)
                : nil

            var moment = Moment(
                id: id,
                gameId: gId,
                momentCategory: category,
                startTimestampMs: startMs,
                endTimestampMs: endMs,
                durationMs: durationMs,
                notes: notes,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000.0),
                modifiedAt: modifiedAt != nil ? Date(timeIntervalSince1970: TimeInterval(modifiedAt!) / 1000.0) : nil
            )

            // Load labels for this tag
            moment.layers = getLayers(momentId: id)

            moments.append(moment)
        }

        print("📊 DatabaseManager.getMomentsForProject: Returning \(moments.count) moments for project \(projectId)")
        return moments
    }

    /// Get all tags for a game (with their labels)
    func getMoments(gameId: String) -> [Moment] {
        guard let db = db else {
            print("❌ DatabaseManager.getTags: No database connection")
            return []
        }

        print("📍 DatabaseManager.getTags: Using database at \(dbPath)")
        print("   🔍 Querying for gameId: \(gameId)")

        let query = """
            SELECT tag_id, game_id, tag_category, start_timestamp_ms, end_timestamp_ms,
                   duration_ms, notes, created_at, modified_at
            FROM tags
            WHERE game_id = ?
            ORDER BY start_timestamp_ms ASC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getTags: Failed to prepare: \(error)")
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        gameId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var moments: [Moment] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let gId = String(cString: sqlite3_column_text(statement, 1))
            let category = String(cString: sqlite3_column_text(statement, 2))
            let startMs = sqlite3_column_int64(statement, 3)
            let endMs = sqlite3_column_type(statement, 4) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 4)
                : nil
            let durationMs = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 5)
                : nil
            let notes = sqlite3_column_type(statement, 6) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 6))
                : nil
            let createdAt = sqlite3_column_int64(statement, 7)
            let modifiedAt = sqlite3_column_type(statement, 8) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 8)
                : nil

            var moment = Moment(
                id: id,
                gameId: gId,
                momentCategory: category,
                startTimestampMs: startMs,
                endTimestampMs: endMs,
                durationMs: durationMs,
                notes: notes,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000.0),
                modifiedAt: modifiedAt != nil ? Date(timeIntervalSince1970: TimeInterval(modifiedAt!) / 1000.0) : nil
            )

            // Load labels for this tag
            moment.layers = getLayers(momentId: id)

            moments.append(moment)
        }

        print("📊 DatabaseManager.getTags: Returning \(moments.count) tags for game \(gameId)")
        return moments
    }

    /// Get the currently active tag for a game (if any)
    func getActiveMoment(gameId: String) -> Moment? {
        guard let db = db else {
            print("❌ DatabaseManager.getActiveTag: No database connection")
            return nil
        }

        let query = """
            SELECT tag_id, game_id, tag_category, start_timestamp_ms, end_timestamp_ms,
                   duration_ms, notes, created_at, modified_at
            FROM tags
            WHERE game_id = ? AND end_timestamp_ms IS NULL
            ORDER BY start_timestamp_ms DESC
            LIMIT 1
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getActiveTag: Failed to prepare: \(error)")
            return nil
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        gameId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let gId = String(cString: sqlite3_column_text(statement, 1))
            let category = String(cString: sqlite3_column_text(statement, 2))
            let startMs = sqlite3_column_int64(statement, 3)
            let notes = sqlite3_column_type(statement, 6) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 6))
                : nil
            let createdAt = sqlite3_column_int64(statement, 7)

            var moment = Moment(
                id: id,
                gameId: gId,
                momentCategory: category,
                startTimestampMs: startMs,
                notes: notes,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000.0)
            )

            // Load labels
            moment.layers = getLayers(momentId: id)

            print("📊 DatabaseManager.getActiveTag: Found active '\(category)' tag")
            return moment
        }

        return nil
    }

    /// Delete all tags for a game
    func deleteAllMoments(gameId: String) -> Result<Void, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let query = "DELETE FROM tags WHERE game_id = ?"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.deleteAllTags: Failed to prepare: \(error)")
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        gameId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.deleteAllTags: Failed to delete: \(error)")
            return .failure(.executionFailed(error))
        }

        print("✅ DatabaseManager.deleteAllTags: Deleted all tags for game \(gameId)")
        return .success(())
    }

    /// Delete a tag
    func deleteMoment(momentId: String) -> Result<Void, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let query = "DELETE FROM tags WHERE tag_id = ?"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        momentId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(.executionFailed(error))
        }

        print("✅ DatabaseManager.deleteMoment: Deleted moment \(momentId)")
        return .success(())
    }

    // MARK: - Labels Management (Metadata attached to tags)

    /// Add a label to a tag
    func addLayer(momentId: String, layerType: String, value: String? = nil, timestampMs: Int64? = nil) -> Result<Layer, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let layerId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        let query = """
            INSERT INTO labels (
                label_id, tag_id, label_type, timestamp_ms, value, created_at
            ) VALUES (?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.addLabel: Failed to prepare: \(error)")
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        layerId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        momentId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        layerType.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }

        if let ts = timestampMs {
            sqlite3_bind_int64(statement, 4, ts)
        } else {
            sqlite3_bind_null(statement, 4)
        }

        if let v = value {
            v.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 5)
        }

        sqlite3_bind_int64(statement, 6, now)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.addLabel: Failed to insert: \(error)")
            return .failure(.executionFailed(error))
        }

        let layer = Layer(
            id: layerId,
            momentId: momentId,
            layerType: layerType,
            timestampMs: timestampMs,
            value: value,
            createdAt: Date(timeIntervalSince1970: TimeInterval(now) / 1000.0)
        )

        print("✅ DatabaseManager.addLayer: Added '\(layerType)' layer to moment \(momentId)")
        return .success(layer)
    }

    /// Get all labels for a tag
    func getLayers(momentId: String) -> [Layer] {
        guard let db = db else {
            print("❌ DatabaseManager.getLayers: No database connection")
            return []
        }

        let query = """
            SELECT label_id, tag_id, label_type, timestamp_ms, value, created_at
            FROM labels
            WHERE tag_id = ?
            ORDER BY created_at ASC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getLayers: Failed to prepare: \(error)")
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        momentId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var layers: [Layer] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let tId = String(cString: sqlite3_column_text(statement, 1))
            let layerType = String(cString: sqlite3_column_text(statement, 2))
            let timestampMs = sqlite3_column_type(statement, 3) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 3)
                : nil
            let value = sqlite3_column_type(statement, 4) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 4))
                : nil
            let createdAt = sqlite3_column_int64(statement, 5)

            let layer = Layer(
                id: id,
                momentId: tId,
                layerType: layerType,
                timestampMs: timestampMs,
                value: value,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000.0)
            )

            layers.append(layer)
        }

        return layers
    }

    /// Delete a label
    func deleteLayer(layerId: String) -> Result<Void, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let query = "DELETE FROM labels WHERE label_id = ?"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        layerId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(.executionFailed(error))
        }

        print("✅ DatabaseManager.deleteLayer: Deleted layer \(layerId)")
        return .success(())
    }

    // MARK: - Possessions Management

    /// Create a new possession
    func createPossession(
        gameId: String,
        teamType: String,
        startTimeMs: Int64,
        period: Int,
        startTrigger: String
    ) -> Result<String, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let possessionId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        let query = """
            INSERT INTO possessions (
                possession_id, game_id, team_type, start_time_ms, period,
                start_trigger, points_scored, tag_count, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.createPossession: Failed to prepare: \(error)")
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        possessionId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        gameId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        teamType.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 4, startTimeMs)
        sqlite3_bind_int(statement, 5, Int32(period))
        startTrigger.withCString { sqlite3_bind_text(statement, 6, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 7, now)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.createPossession: Failed to insert: \(error)")
            return .failure(.executionFailed(error))
        }

        print("✅ DatabaseManager.createPossession: Created possession at \(startTimeMs)ms")
        return .success(possessionId)
    }

    /// End a possession
    func endPossession(
        possessionId: String,
        endTimeMs: Int64,
        endTrigger: String,
        outcome: String,
        pointsScored: Int
    ) -> Result<Void, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let query = """
            UPDATE possessions
            SET end_time_ms = ?,
                end_trigger = ?,
                outcome = ?,
                points_scored = ?,
                duration_ms = ? - start_time_ms,
                modified_at = ?
            WHERE possession_id = ?
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        sqlite3_bind_int64(statement, 1, endTimeMs)
        endTrigger.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        outcome.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int(statement, 4, Int32(pointsScored))
        sqlite3_bind_int64(statement, 5, endTimeMs)
        sqlite3_bind_int64(statement, 6, now)
        possessionId.withCString { sqlite3_bind_text(statement, 7, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(.executionFailed(error))
        }

        print("✅ DatabaseManager.endPossession: Ended possession \(possessionId)")
        return .success(())
    }

    /// Get all possessions for a game
    func getPossessions(gameId: String) -> [Possession] {
        guard let db = db else {
            print("❌ DatabaseManager.getPossessions: No database connection")
            return []
        }

        let query = """
            SELECT possession_id, game_id, team_type, start_time_ms, end_time_ms,
                   period, start_trigger, end_trigger, outcome, points_scored,
                   tag_count, notes, created_at
            FROM possessions
            WHERE game_id = ?
            ORDER BY start_time_ms ASC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getPossessions: Failed to prepare: \(error)")
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        gameId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var possessions: [Possession] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            // Parse possession fields and construct Possession object
            // This is a placeholder - will need to match the actual Possession struct
            print("✅ Found possession in database")
        }

        return possessions
    }

    /// Get active (unclosed) possession for a game
    func getActivePossession(gameId: String) -> Possession? {
        guard let db = db else {
            return nil
        }

        let query = """
            SELECT possession_id, game_id, team_type, start_time_ms, end_time_ms,
                   period, start_trigger, end_trigger, outcome, points_scored,
                   tag_count, notes, created_at
            FROM possessions
            WHERE game_id = ? AND end_time_ms IS NULL
            ORDER BY start_time_ms DESC
            LIMIT 1
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            return nil
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        gameId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) == SQLITE_ROW {
            // Parse and return the active possession
            // This is a placeholder - will need to match the actual Possession struct
            print("✅ Found active possession")
            return nil
        }

        return nil
    }

    // MARK: - Annotations

    /// Save annotations for a project (with transaction)
    func saveAnnotations(_ annotationsData: [[String: Any]], projectId: String) -> Result<Void, DatabaseError> {
        var result: Result<Void, DatabaseError>!
        
        dbQueue.sync {
            guard let db = self.db else {
                result = .failure(.noDatabase)
                return
            }

            // Begin transaction for atomic operation
            if sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) != SQLITE_OK {
                result = .failure(.executionFailed("Failed to begin transaction"))
                return
            }

            // Delete existing annotations for this project
            let deleteQuery = "DELETE FROM annotations WHERE project_id = ?"
            var deleteStatement: OpaquePointer?
            defer { sqlite3_finalize(deleteStatement) }

            if sqlite3_prepare_v2(db, deleteQuery, -1, &deleteStatement, nil) != SQLITE_OK {
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                result = .failure(.prepareFailed("Failed to prepare delete statement"))
                return
            }

            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            projectId.withCString { sqlite3_bind_text(deleteStatement, 1, $0, -1, SQLITE_TRANSIENT) }

            if sqlite3_step(deleteStatement) != SQLITE_DONE {
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                result = .failure(.executionFailed("Failed to delete old annotations"))
                return
            }

            // Insert new annotations
            let insertQuery = """
                INSERT INTO annotations (annotation_id, project_id, video_id, angle_id, annotation_type,
                                       annotation_data, start_time_ms, end_time_ms, color, stroke_width,
                                       opacity, is_visible, is_locked, created_at, modified_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

            for annotationDict in annotationsData {
                var statement: OpaquePointer?
                defer { sqlite3_finalize(statement) }

                if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) != SQLITE_OK {
                    result = .failure(.prepareFailed("Failed to prepare insert statement"))
                    return
                }

                // Bind parameters
                if let id = annotationDict["id"] as? String {
                    id.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
                }
                projectId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }

                if let videoId = annotationDict["videoId"] as? String {
                    videoId.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
                } else {
                    sqlite3_bind_null(statement, 3)
                }

                if let angleId = annotationDict["angleId"] as? String {
                    angleId.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
                }

                if let type = annotationDict["type"] as? String {
                    type.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }
                }

                if let data = annotationDict["data"] as? String {
                    data.withCString { sqlite3_bind_text(statement, 6, $0, -1, SQLITE_TRANSIENT) }
                }

                if let startTime = annotationDict["startTimeMs"] as? Int64 {
                    sqlite3_bind_int64(statement, 7, startTime)
                }

                if let endTime = annotationDict["endTimeMs"] as? Int64 {
                    sqlite3_bind_int64(statement, 8, endTime)
                }

                let color = (annotationDict["color"] as? String) ?? "#FFFFFF"
                color.withCString { sqlite3_bind_text(statement, 9, $0, -1, SQLITE_TRANSIENT) }

                let strokeWidth = (annotationDict["strokeWidth"] as? Double) ?? 2.0
                sqlite3_bind_double(statement, 10, strokeWidth)

                let opacity = (annotationDict["opacity"] as? Double) ?? 1.0
                sqlite3_bind_double(statement, 11, opacity)

                if let isVisible = annotationDict["isVisible"] as? Bool {
                    sqlite3_bind_int(statement, 12, isVisible ? 1 : 0)
                }

                if let isLocked = annotationDict["isLocked"] as? Bool {
                    sqlite3_bind_int(statement, 13, isLocked ? 1 : 0)
                }

                let createdAt = Int64(Date().timeIntervalSince1970)
                sqlite3_bind_int64(statement, 14, createdAt)
                sqlite3_bind_int64(statement, 15, createdAt)

                if sqlite3_step(statement) != SQLITE_DONE {
                    let errorMessage = String(cString: sqlite3_errmsg(db))
                    sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                    result = .failure(.executionFailed("Failed to insert annotation: \(errorMessage)"))
                    return
                }
            }

            // Commit transaction
            if sqlite3_exec(db, "COMMIT", nil, nil, nil) != SQLITE_OK {
                sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                result = .failure(.executionFailed("Failed to commit transaction"))
                return
            }

            print("✅ Saved \(annotationsData.count) annotations for project \(projectId)")
            result = .success(())
        }
        
        return result
    }

    /// Load annotations for a project
    func loadAnnotations(projectId: String) -> [[String: Any]] {
        var annotations: [[String: Any]] = []

        dbQueue.sync {
            guard let db = self.db else {
                print("❌ DatabaseManager.loadAnnotations: No database connection")
                return
            }

            // First check if annotations table exists
            let tableCheckQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='annotations';"
            var tableCheckStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, tableCheckQuery, -1, &tableCheckStmt, nil) == SQLITE_OK {
                let tableExists = sqlite3_step(tableCheckStmt) == SQLITE_ROW
                sqlite3_finalize(tableCheckStmt)

                if !tableExists {
                    print("⚠️ DatabaseManager.loadAnnotations: Annotations table doesn't exist yet")
                    return
                }
            }

            let query = """
                SELECT annotation_id, video_id, angle_id, annotation_type, annotation_data,
                       start_time_ms, end_time_ms, color, stroke_width, opacity,
                       is_visible, is_locked, created_at
                FROM annotations
                WHERE project_id = ?
                ORDER BY created_at ASC
            """

            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("❌ DatabaseManager.loadAnnotations: Failed to prepare query: \(errorMessage)")
                print("   Database path: \(self.dbPath)")
                return
            }

            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            projectId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

            while sqlite3_step(statement) == SQLITE_ROW {
                var annotation: [String: Any] = [:]

                if let id = sqlite3_column_text(statement, 0) {
                    annotation["id"] = String(cString: id)
                }

                if let videoId = sqlite3_column_text(statement, 1) {
                    annotation["videoId"] = String(cString: videoId)
                }

                if let angleId = sqlite3_column_text(statement, 2) {
                    annotation["angleId"] = String(cString: angleId)
                }

                if let type = sqlite3_column_text(statement, 3) {
                    annotation["type"] = String(cString: type)
                }

                if let data = sqlite3_column_text(statement, 4) {
                    annotation["data"] = String(cString: data)
                }

                annotation["startTimeMs"] = sqlite3_column_int64(statement, 5)
                annotation["endTimeMs"] = sqlite3_column_int64(statement, 6)

                if let color = sqlite3_column_text(statement, 7) {
                    annotation["color"] = String(cString: color)
                }

                annotation["strokeWidth"] = sqlite3_column_double(statement, 8)
                annotation["opacity"] = sqlite3_column_double(statement, 9)
                annotation["isVisible"] = sqlite3_column_int(statement, 10) == 1
                annotation["isLocked"] = sqlite3_column_int(statement, 11) == 1

                annotations.append(annotation)
            }

            print("✅ DatabaseManager.loadAnnotations: Loaded \(annotations.count) annotations for project \(projectId)")
        }

        return annotations
    }

    // MARK: - Blueprints

    /// Save a blueprint to the database
    func saveBlueprint(_ blueprint: Blueprint) -> Result<Blueprint, DatabaseError> {
        guard let db = db else {
            return .failure(.connectionError)
        }

        // Serialize moments and layers to JSON
        let encoder = JSONEncoder()
        guard let momentsData = try? encoder.encode(blueprint.moments),
              let momentsJSON = String(data: momentsData, encoding: .utf8),
              let layersData = try? encoder.encode(blueprint.layers),
              let layersJSON = String(data: layersData, encoding: .utf8) else {
            return .failure(.serializationError)
        }

        let query = """
        INSERT OR REPLACE INTO blueprints (blueprint_id, name, moments_json, layers_json, created_at, modified_at, is_default)
        VALUES (?, ?, ?, ?, ?, ?, 0)
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare saveBlueprint query")
            return .failure(.queryPreparationFailed)
        }

        defer { sqlite3_finalize(statement) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let createdAtMs = Int64(blueprint.createdAt.timeIntervalSince1970 * 1000)
        let modifiedAtMs = blueprint.modifiedAt.map { Int64($0.timeIntervalSince1970 * 1000) } ?? createdAtMs

        blueprint.id.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        blueprint.name.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        momentsJSON.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        layersJSON.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 5, createdAtMs)
        sqlite3_bind_int64(statement, 6, modifiedAtMs)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            print("❌ Failed to save blueprint: \(String(cString: sqlite3_errmsg(db)))")
            return .failure(.insertFailed)
        }

        print("✅ Saved blueprint: \(blueprint.name)")
        return .success(blueprint)
    }

    /// Update an existing blueprint
    func updateBlueprint(_ blueprint: Blueprint) -> Result<Blueprint, DatabaseError> {
        guard let db = db else {
            return .failure(.connectionError)
        }

        // Serialize moments and layers to JSON
        let encoder = JSONEncoder()
        guard let momentsData = try? encoder.encode(blueprint.moments),
              let momentsJSON = String(data: momentsData, encoding: .utf8),
              let layersData = try? encoder.encode(blueprint.layers),
              let layersJSON = String(data: layersData, encoding: .utf8) else {
            return .failure(.serializationError)
        }

        let query = """
        UPDATE blueprints
        SET name = ?, moments_json = ?, layers_json = ?, modified_at = ?
        WHERE blueprint_id = ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return .failure(.queryPreparationFailed)
        }

        defer { sqlite3_finalize(statement) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let modifiedAtMs = Int64(Date().timeIntervalSince1970 * 1000)

        blueprint.name.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        momentsJSON.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        layersJSON.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 4, modifiedAtMs)
        blueprint.id.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            return .failure(.updateFailed)
        }

        var updatedBlueprint = blueprint
        updatedBlueprint.modifiedAt = Date()

        print("✅ Updated blueprint: \(blueprint.name)")
        return .success(updatedBlueprint)
    }

    /// Get all blueprints
    func getBlueprints() -> [Blueprint] {
        guard let db = db else {
            print("❌ No database connection")
            return []
        }

        let query = "SELECT blueprint_id, name, moments_json, layers_json, created_at, modified_at FROM blueprints ORDER BY is_default DESC, name ASC"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Failed to prepare getBlueprints query")
            return []
        }

        defer { sqlite3_finalize(statement) }

        var blueprints: [Blueprint] = []
        let decoder = JSONDecoder()

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idCStr = sqlite3_column_text(statement, 0),
                  let nameCStr = sqlite3_column_text(statement, 1),
                  let momentsJSONCStr = sqlite3_column_text(statement, 2),
                  let layersJSONCStr = sqlite3_column_text(statement, 3) else {
                continue
            }

            let id = String(cString: idCStr)
            let name = String(cString: nameCStr)
            let momentsJSON = String(cString: momentsJSONCStr)
            let layersJSON = String(cString: layersJSONCStr)
            let createdAtMs = sqlite3_column_int64(statement, 4)
            let modifiedAtMs = sqlite3_column_int64(statement, 5)

            // Deserialize moments and layers
            guard let momentsData = momentsJSON.data(using: .utf8),
                  let moments = try? decoder.decode([MomentButton].self, from: momentsData),
                  let layersData = layersJSON.data(using: .utf8),
                  let layers = try? decoder.decode([LayerButton].self, from: layersData) else {
                print("⚠️ Failed to decode blueprint: \(name)")
                continue
            }

            let blueprint = Blueprint(
                id: id,
                name: name,
                moments: moments,
                layers: layers,
                createdAt: Date(timeIntervalSince1970: Double(createdAtMs) / 1000.0),
                modifiedAt: modifiedAtMs > 0 ? Date(timeIntervalSince1970: Double(modifiedAtMs) / 1000.0) : nil
            )

            blueprints.append(blueprint)
        }

        print("✅ Loaded \(blueprints.count) blueprints")
        return blueprints
    }

    /// Get a specific blueprint by ID
    func getBlueprint(id: String) -> Blueprint? {
        return getBlueprints().first { $0.id == id }
    }

    /// Delete a blueprint
    func deleteBlueprint(id: String) -> Result<Void, DatabaseError> {
        guard let db = db else {
            return .failure(.connectionError)
        }

        let query = "DELETE FROM blueprints WHERE blueprint_id = ?"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return .failure(.queryPreparationFailed)
        }

        defer { sqlite3_finalize(statement) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        id.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            return .failure(.deleteFailed)
        }

        print("✅ Deleted blueprint: \(id)")
        return .success(())
    }

    // MARK: - Notes Management

    /// Create a new note
    func createNote(
        momentId: String?,
        gameId: String,
        content: String,
        attachedTo: [NoteAttachment],
        playerId: String? = nil
    ) -> Result<String, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let noteId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        // Serialize attachments to JSON
        let attachmentsJSON: String
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(attachedTo)
            attachmentsJSON = String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            print("❌ Failed to encode attachments: \(error)")
            return .failure(.serializationError)
        }

        let query = """
            INSERT INTO notes (note_id, moment_id, game_id, content, attached_to, player_id, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(.prepareFailed(error))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        noteId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        if let momentId = momentId {
            momentId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 2)
        }
        gameId.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        content.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
        attachmentsJSON.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }
        if let playerId = playerId {
            playerId.withCString { sqlite3_bind_text(statement, 6, $0, -1, SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(statement, 6)
        }
        sqlite3_bind_int64(statement, 7, now)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ Failed to create note: \(error)")
            return .failure(.executionFailed(error))
        }

        if let momentId = momentId {
            print("✅ Created note for moment \(momentId)")
        } else {
            print("✅ Created standalone note")
        }
        return .success(noteId)
    }

    /// Get all notes for a project (across all games)
    func getAllNotesForProject(projectId: String) -> [Note] {
        guard let db = db else {
            print("❌ DatabaseManager.getAllNotesForProject: No database connection")
            return []
        }

        print("📍 DatabaseManager.getAllNotesForProject: Using database at \(dbPath ?? "unknown")")
        print("   🔍 Querying for projectId: \(projectId)")

        // First, check if notes table exists
        let tableCheckQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='notes';"
        var tableCheckStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, tableCheckQuery, -1, &tableCheckStmt, nil) == SQLITE_OK {
            if sqlite3_step(tableCheckStmt) == SQLITE_ROW {
                print("   ✅ Notes table exists")
            } else {
                print("   ⚠️ Notes table does NOT exist!")
            }
            sqlite3_finalize(tableCheckStmt)
        }

        // Check total count of notes across all games in the project
        let countQuery = """
            SELECT COUNT(*) FROM notes n
            INNER JOIN games g ON n.game_id = g.game_id
            WHERE g.project_id = ?;
        """
        var countStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, countQuery, -1, &countStmt, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            projectId.withCString { sqlite3_bind_text(countStmt, 1, $0, -1, SQLITE_TRANSIENT) }
            if sqlite3_step(countStmt) == SQLITE_ROW {
                let count = sqlite3_column_int(countStmt, 0)
                print("   📊 Found \(count) notes across all games in project")
            }
            sqlite3_finalize(countStmt)
        }

        // Query notes from all games in the project
        let query = """
            SELECT n.note_id, n.moment_id, n.game_id, n.content, n.attached_to, n.player_id, n.created_at, n.modified_at
            FROM notes n
            INNER JOIN games g ON n.game_id = g.game_id
            WHERE g.project_id = ?
            ORDER BY n.created_at DESC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getAllNotesForProject: Prepare failed: \(error)")
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        projectId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var notes: [Note] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let noteIdPtr = sqlite3_column_text(statement, 0),
                  let gameIdPtr = sqlite3_column_text(statement, 2),
                  let contentPtr = sqlite3_column_text(statement, 3),
                  let attachedToPtr = sqlite3_column_text(statement, 4) else {
                continue
            }

            let noteId = String(cString: noteIdPtr)

            // moment_id can be NULL for standalone notes
            let momentId: String
            if sqlite3_column_type(statement, 1) != SQLITE_NULL,
               let momentIdPtr = sqlite3_column_text(statement, 1) {
                momentId = String(cString: momentIdPtr)
            } else {
                momentId = "" // Empty string for standalone notes
            }

            let gameId = String(cString: gameIdPtr)
            let content = String(cString: contentPtr)
            let attachedToJSON = String(cString: attachedToPtr)

            // Deserialize attachments from JSON
            var attachedTo: [NoteAttachment] = []
            if let data = attachedToJSON.data(using: .utf8) {
                let decoder = JSONDecoder()
                attachedTo = (try? decoder.decode([NoteAttachment].self, from: data)) ?? []
            }

            let playerId = sqlite3_column_type(statement, 5) != SQLITE_NULL ?
                String(cString: sqlite3_column_text(statement, 5)!) : nil

            let createdAtMs = sqlite3_column_int64(statement, 6)
            let createdAt = Date(timeIntervalSince1970: Double(createdAtMs) / 1000.0)

            let modifiedAtMs = sqlite3_column_int64(statement, 7)
            let modifiedAt = modifiedAtMs > 0 ? Date(timeIntervalSince1970: Double(modifiedAtMs) / 1000.0) : nil

            let note = Note(
                id: noteId,
                momentId: momentId,
                gameId: gameId,
                content: content,
                attachedTo: attachedTo,
                playerId: playerId,
                createdAt: createdAt,
                modifiedAt: modifiedAt
            )

            notes.append(note)
        }

        print("📊 DatabaseManager.getAllNotesForProject: Returning \(notes.count) notes for project \(projectId)")
        return notes
    }

    /// Get all notes for a specific game
    func getAllNotes(gameId: String) -> [Note] {
        guard let db = db else {
            print("❌ DatabaseManager.getAllNotes: No database connection")
            return []
        }

        print("📍 DatabaseManager.getAllNotes: Using database at \(dbPath ?? "unknown")")
        print("   🔍 Querying for gameId: \(gameId)")

        let query = """
            SELECT note_id, moment_id, game_id, content, attached_to, player_id, created_at, modified_at
            FROM notes
            WHERE game_id = ?
            ORDER BY created_at DESC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getAllNotes: Prepare failed: \(error)")
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        gameId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var notes: [Note] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let noteIdPtr = sqlite3_column_text(statement, 0),
                  let gameIdPtr = sqlite3_column_text(statement, 2),
                  let contentPtr = sqlite3_column_text(statement, 3),
                  let attachedToPtr = sqlite3_column_text(statement, 4) else {
                continue
            }

            let noteId = String(cString: noteIdPtr)

            // moment_id can be NULL for standalone notes
            let momentId: String
            if sqlite3_column_type(statement, 1) != SQLITE_NULL,
               let momentIdPtr = sqlite3_column_text(statement, 1) {
                momentId = String(cString: momentIdPtr)
            } else {
                momentId = "" // Empty string for standalone notes
            }

            let gameId = String(cString: gameIdPtr)
            let content = String(cString: contentPtr)
            let attachedToJSON = String(cString: attachedToPtr)

            // Deserialize attachments from JSON
            var attachedTo: [NoteAttachment] = []
            if let data = attachedToJSON.data(using: .utf8) {
                let decoder = JSONDecoder()
                attachedTo = (try? decoder.decode([NoteAttachment].self, from: data)) ?? []
            }

            let playerId = sqlite3_column_type(statement, 5) != SQLITE_NULL ?
                String(cString: sqlite3_column_text(statement, 5)!) : nil

            let createdAtMs = sqlite3_column_int64(statement, 6)
            let createdAt = Date(timeIntervalSince1970: Double(createdAtMs) / 1000.0)

            let modifiedAtMs = sqlite3_column_int64(statement, 7)
            let modifiedAt = modifiedAtMs > 0 ? Date(timeIntervalSince1970: Double(modifiedAtMs) / 1000.0) : nil

            let note = Note(
                id: noteId,
                momentId: momentId,
                gameId: gameId,
                content: content,
                attachedTo: attachedTo,
                playerId: playerId,
                createdAt: createdAt,
                modifiedAt: modifiedAt
            )

            notes.append(note)
        }

        print("📊 DatabaseManager.getAllNotes: Returning \(notes.count) notes for game \(gameId)")
        return notes
    }

    /// Get all notes for a specific moment
    func getNotes(momentId: String, gameId: String) -> [Note] {
        guard let db = db else {
            print("❌ DatabaseManager.getNotes: No database connection")
            return []
        }

        let query = """
            SELECT note_id, moment_id, game_id, content, attached_to, player_id, created_at, modified_at
            FROM notes
            WHERE moment_id = ? AND game_id = ?
            ORDER BY created_at DESC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getNotes: Prepare failed: \(error)")
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        momentId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        gameId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }

        var notes: [Note] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let noteIdPtr = sqlite3_column_text(statement, 0),
                  let momentIdPtr = sqlite3_column_text(statement, 1),
                  let gameIdPtr = sqlite3_column_text(statement, 2),
                  let contentPtr = sqlite3_column_text(statement, 3),
                  let attachedToPtr = sqlite3_column_text(statement, 4) else {
                continue
            }

            let noteId = String(cString: noteIdPtr)
            let momentId = String(cString: momentIdPtr)
            let gameId = String(cString: gameIdPtr)
            let content = String(cString: contentPtr)
            let attachedToJSON = String(cString: attachedToPtr)

            // Deserialize attachments from JSON
            var attachedTo: [NoteAttachment] = []
            if let data = attachedToJSON.data(using: .utf8) {
                let decoder = JSONDecoder()
                attachedTo = (try? decoder.decode([NoteAttachment].self, from: data)) ?? []
            }

            let playerId = sqlite3_column_type(statement, 5) != SQLITE_NULL ?
                String(cString: sqlite3_column_text(statement, 5)!) : nil

            let createdAtMs = sqlite3_column_int64(statement, 6)
            let createdAt = Date(timeIntervalSince1970: Double(createdAtMs) / 1000.0)

            let modifiedAtMs = sqlite3_column_int64(statement, 7)
            let modifiedAt = modifiedAtMs > 0 ? Date(timeIntervalSince1970: Double(modifiedAtMs) / 1000.0) : nil

            let note = Note(
                id: noteId,
                momentId: momentId,
                gameId: gameId,
                content: content,
                attachedTo: attachedTo,
                playerId: playerId,
                createdAt: createdAt,
                modifiedAt: modifiedAt
            )

            notes.append(note)
        }

        return notes
    }

    /// Update a note's content
    func updateNote(noteId: String, content: String) -> Bool {
        guard let db = db else {
            print("❌ DatabaseManager.updateNote: No database connection")
            return false
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let query = """
            UPDATE notes
            SET content = ?, modified_at = ?
            WHERE note_id = ?
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.updateNote: Prepare failed: \(error)")
            return false
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        content.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 2, now)
        noteId.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.updateNote: Execution failed: \(error)")
            return false
        }

        print("✅ Updated note \(noteId)")
        return true
    }

    /// Delete a note
    func deleteNote(noteId: String) -> Bool {
        guard let db = db else {
            print("❌ DatabaseManager.deleteNote: No database connection")
            return false
        }

        let query = "DELETE FROM notes WHERE note_id = ?"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.deleteNote: Prepare failed: \(error)")
            return false
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        noteId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.deleteNote: Execution failed: \(error)")
            return false
        }

        print("✅ Deleted note \(noteId)")
        return true
    }

    // MARK: - Categories Management

    /// Create a new category
    func createCategory(name: String, color: String) -> Result<Category, DatabaseError> {
        guard let db = db else {
            return .failure(.noDatabase)
        }

        let categoryId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        // Get next sort order
        var maxSortOrder = 0
        let countQuery = "SELECT MAX(sort_order) FROM categories"
        var countStatement: OpaquePointer?

        if sqlite3_prepare_v2(db, countQuery, -1, &countStatement, nil) == SQLITE_OK {
            if sqlite3_step(countStatement) == SQLITE_ROW {
                maxSortOrder = Int(sqlite3_column_int(countStatement, 0))
            }
        }
        sqlite3_finalize(countStatement)

        let query = """
            INSERT INTO categories (
                category_id, name, color, sort_order, created_at
            ) VALUES (?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.createCategory: Preparation failed: \(error)")
            return .failure(.prepareFailed(error))
        }

        defer { sqlite3_finalize(statement) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        categoryId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        name.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        color.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int(statement, 4, Int32(maxSortOrder + 1))
        sqlite3_bind_int64(statement, 5, now)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.createCategory: Execution failed: \(error)")
            return .failure(.executionFailed(error))
        }

        let category = Category(
            id: categoryId,
            name: name,
            color: color,
            sortOrder: maxSortOrder + 1,
            createdAt: Date(timeIntervalSince1970: TimeInterval(now) / 1000.0)
        )

        print("✅ DatabaseManager.createCategory: Created '\(name)' category")
        return .success(category)
    }

    /// Get all categories sorted by sort_order
    func getCategories() -> [Category] {
        guard let db = db else {
            print("❌ DatabaseManager.getCategories: No database connection")
            return []
        }

        let query = """
            SELECT category_id, name, color, sort_order, created_at, modified_at
            FROM categories
            ORDER BY sort_order ASC
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.getCategories: Preparation failed: \(error)")
            return []
        }

        defer { sqlite3_finalize(statement) }

        var categories: [Category] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let name = String(cString: sqlite3_column_text(statement, 1))
            let color = String(cString: sqlite3_column_text(statement, 2))
            let sortOrder = Int(sqlite3_column_int(statement, 3))
            let createdAt = sqlite3_column_int64(statement, 4)
            let modifiedAt = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? sqlite3_column_int64(statement, 5)
                : nil

            let category = Category(
                id: id,
                name: name,
                color: color,
                sortOrder: sortOrder,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000.0),
                modifiedAt: modifiedAt != nil ? Date(timeIntervalSince1970: TimeInterval(modifiedAt!) / 1000.0) : nil
            )

            categories.append(category)
        }

        print("📋 DatabaseManager.getCategories: Found \(categories.count) categories")
        return categories
    }

    /// Update a category
    func updateCategory(_ category: Category) -> Bool {
        guard let db = db else {
            print("❌ DatabaseManager.updateCategory: No database connection")
            return false
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)

        let query = """
            UPDATE categories
            SET name = ?, color = ?, sort_order = ?, modified_at = ?
            WHERE category_id = ?
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.updateCategory: Preparation failed: \(error)")
            return false
        }

        defer { sqlite3_finalize(statement) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        category.name.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        category.color.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int(statement, 3, Int32(category.sortOrder))
        sqlite3_bind_int64(statement, 4, now)
        category.id.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.updateCategory: Execution failed: \(error)")
            return false
        }

        print("✅ DatabaseManager.updateCategory: Updated '\(category.name)' category")
        return true
    }

    /// Delete a category
    func deleteCategory(_ categoryId: String) -> Bool {
        guard let db = db else {
            print("❌ DatabaseManager.deleteCategory: No database connection")
            return false
        }

        let query = "DELETE FROM categories WHERE category_id = ?"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.deleteCategory: Preparation failed: \(error)")
            return false
        }

        defer { sqlite3_finalize(statement) }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        categoryId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            print("❌ DatabaseManager.deleteCategory: Execution failed: \(error)")
            return false
        }

        print("✅ DatabaseManager.deleteCategory: Deleted category \(categoryId)")
        return true
    }
}
