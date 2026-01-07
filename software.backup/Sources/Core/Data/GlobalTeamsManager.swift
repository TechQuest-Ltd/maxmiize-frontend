//
//  GlobalTeamsManager.swift
//  maxmiize-v1
//
//  Created by TechQuest on 15/12/2025.
//

import Foundation
import SQLite3

/// Manages teams and players globally (not tied to specific projects)
/// Stored in ~/Library/Application Support/Maxmiize/teams.db
class GlobalTeamsManager {
    nonisolated(unsafe) static let shared = GlobalTeamsManager()

    private var db: OpaquePointer?
    private let dbPath: String

    private init() {
        // Store in Application Support (persists across app launches)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let maxmiizeDir = appSupport.appendingPathComponent("Maxmiize")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: maxmiizeDir, withIntermediateDirectories: true)

        dbPath = maxmiizeDir.appendingPathComponent("teams.db").path
        print("📁 Global Teams DB path: \(dbPath)")

        openDatabase()
        createTables()
    }

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ Error opening global teams database")
        } else {
            print("✅ Global teams database opened successfully")
        }
    }

    private func migrateDatabase() {
        guard let db = db else { return }

        // Check if teams table exists and if it has sport_type_id column
        let checkQuery = "PRAGMA table_info(teams)"
        var statement: OpaquePointer?
        var hasSportTypeId = false

        if sqlite3_prepare_v2(db, checkQuery, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let namePtr = sqlite3_column_text(statement, 1) {
                    let columnName = String(cString: namePtr)
                    if columnName == "sport_type_id" {
                        hasSportTypeId = true
                        break
                    }
                }
            }
        }
        sqlite3_finalize(statement)

        // If teams table exists but doesn't have sport_type_id, we need to migrate
        if !hasSportTypeId {
            let tableExistsQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='teams'"
            var tableStatement: OpaquePointer?
            var tableExists = false

            if sqlite3_prepare_v2(db, tableExistsQuery, -1, &tableStatement, nil) == SQLITE_OK {
                if sqlite3_step(tableStatement) == SQLITE_ROW {
                    tableExists = true
                }
            }
            sqlite3_finalize(tableStatement)

            if tableExists {
                print("🔄 Migrating teams table to add sport_type_id column...")

                // Create new sport types and position tables first
                let sportTablesSchema = """
                CREATE TABLE IF NOT EXISTS sport_types (
                    sport_type_id TEXT PRIMARY KEY,
                    name TEXT NOT NULL UNIQUE,
                    created_at INTEGER NOT NULL
                );

                CREATE TABLE IF NOT EXISTS position_groups (
                    position_group_id TEXT PRIMARY KEY,
                    sport_type_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    color TEXT NOT NULL,
                    display_order INTEGER NOT NULL,
                    created_at INTEGER NOT NULL,
                    FOREIGN KEY (sport_type_id) REFERENCES sport_types(sport_type_id) ON DELETE CASCADE,
                    UNIQUE(sport_type_id, name)
                );

                CREATE TABLE IF NOT EXISTS positions (
                    position_id TEXT PRIMARY KEY,
                    position_group_id TEXT NOT NULL,
                    code TEXT NOT NULL,
                    name TEXT NOT NULL,
                    display_order INTEGER NOT NULL,
                    created_at INTEGER NOT NULL,
                    FOREIGN KEY (position_group_id) REFERENCES position_groups(position_group_id) ON DELETE CASCADE,
                    UNIQUE(position_group_id, code)
                );
                """

                var error: UnsafeMutablePointer<Int8>?
                if sqlite3_exec(db, sportTablesSchema, nil, nil, &error) == SQLITE_OK {
                    // Seed basketball sport type and positions
                    let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
                    let basketballId = UUID().uuidString
                    seedSportType(id: basketballId, name: "Basketball", timestamp: timestamp)

                    // Seed basketball position groups and positions
                    let bGuardsId = UUID().uuidString
                    let bForwardsId = UUID().uuidString
                    let bCentersId = UUID().uuidString

                    seedPositionGroup(id: bGuardsId, sportId: basketballId, name: "Guards", color: "2979ff", order: 1, timestamp: timestamp)
                    seedPositionGroup(id: bForwardsId, sportId: basketballId, name: "Forwards", color: "f5c14e", order: 2, timestamp: timestamp)
                    seedPositionGroup(id: bCentersId, sportId: basketballId, name: "Centers", color: "ff5252", order: 3, timestamp: timestamp)

                    seedPosition(groupId: bGuardsId, code: "PG", name: "Point Guard", order: 1, timestamp: timestamp)
                    seedPosition(groupId: bGuardsId, code: "SG", name: "Shooting Guard", order: 2, timestamp: timestamp)
                    seedPosition(groupId: bGuardsId, code: "G", name: "Guard", order: 3, timestamp: timestamp)

                    seedPosition(groupId: bForwardsId, code: "SF", name: "Small Forward", order: 1, timestamp: timestamp)
                    seedPosition(groupId: bForwardsId, code: "PF", name: "Power Forward", order: 2, timestamp: timestamp)
                    seedPosition(groupId: bForwardsId, code: "F", name: "Forward", order: 3, timestamp: timestamp)

                    seedPosition(groupId: bCentersId, code: "C", name: "Center", order: 1, timestamp: timestamp)

                    // Add sport_type_id column with basketball as default
                    let alterQuery = "ALTER TABLE teams ADD COLUMN sport_type_id TEXT DEFAULT '\(basketballId)'"
                    if sqlite3_exec(db, alterQuery, nil, nil, &error) == SQLITE_OK {
                        print("✅ Successfully migrated teams table with Basketball sport")
                    } else {
                        if let error = error {
                            print("❌ Error adding sport_type_id column: \(String(cString: error))")
                            sqlite3_free(error)
                        }
                    }
                } else {
                    if let error = error {
                        print("❌ Error creating sport tables: \(String(cString: error))")
                        sqlite3_free(error)
                    }
                }
            }
        }

        // Check if players table exists and needs position_id column migration
        let checkPlayersQuery = "PRAGMA table_info(players)"
        var playersStatement: OpaquePointer?
        var hasPositionId = false

        if sqlite3_prepare_v2(db, checkPlayersQuery, -1, &playersStatement, nil) == SQLITE_OK {
            while sqlite3_step(playersStatement) == SQLITE_ROW {
                if let namePtr = sqlite3_column_text(playersStatement, 1) {
                    let columnName = String(cString: namePtr)
                    if columnName == "position_id" {
                        hasPositionId = true
                        break
                    }
                }
            }
        }
        sqlite3_finalize(playersStatement)

        // If players table exists but doesn't have position_id, add it
        if !hasPositionId {
            let tableExistsQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name='players'"
            var tableStatement: OpaquePointer?
            var tableExists = false

            if sqlite3_prepare_v2(db, tableExistsQuery, -1, &tableStatement, nil) == SQLITE_OK {
                if sqlite3_step(tableStatement) == SQLITE_ROW {
                    tableExists = true
                }
            }
            sqlite3_finalize(tableStatement)

            if tableExists {
                print("🔄 Migrating players table to add position_id column...")
                let alterQuery = "ALTER TABLE players ADD COLUMN position_id TEXT"
                var error: UnsafeMutablePointer<Int8>?
                if sqlite3_exec(db, alterQuery, nil, nil, &error) == SQLITE_OK {
                    print("✅ Successfully added position_id column to players table")
                } else {
                    if let error = error {
                        print("❌ Migration error: \(String(cString: error))")
                        sqlite3_free(error)
                    }
                }
            }
        }
    }

    private func createTables() {
        // First, run migrations to update existing schema
        migrateDatabase()

        let schema = """
        -- Sport types table
        CREATE TABLE IF NOT EXISTS sport_types (
            sport_type_id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            created_at INTEGER NOT NULL
        );

        -- Position groups table (dynamic per sport)
        CREATE TABLE IF NOT EXISTS position_groups (
            position_group_id TEXT PRIMARY KEY,
            sport_type_id TEXT NOT NULL,
            name TEXT NOT NULL,
            color TEXT NOT NULL,
            display_order INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (sport_type_id) REFERENCES sport_types(sport_type_id) ON DELETE CASCADE,
            UNIQUE(sport_type_id, name)
        );

        -- Positions table (dynamic per position group)
        CREATE TABLE IF NOT EXISTS positions (
            position_id TEXT PRIMARY KEY,
            position_group_id TEXT NOT NULL,
            code TEXT NOT NULL,
            name TEXT NOT NULL,
            display_order INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (position_group_id) REFERENCES position_groups(position_group_id) ON DELETE CASCADE,
            UNIQUE(position_group_id, code)
        );

        -- Teams table (global, not project-specific)
        CREATE TABLE IF NOT EXISTS teams (
            team_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            short_name TEXT,
            organization TEXT,
            sport_type_id TEXT NOT NULL,
            primary_color TEXT DEFAULT '#2979ff',
            secondary_color TEXT,
            logo_path TEXT,
            notes TEXT,
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL,
            FOREIGN KEY (sport_type_id) REFERENCES sport_types(sport_type_id),
            UNIQUE(name, organization)
        );

        -- Players table (belong to teams)
        CREATE TABLE IF NOT EXISTS players (
            player_id TEXT PRIMARY KEY,
            team_id TEXT NOT NULL,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            jersey_number INTEGER NOT NULL,
            position_id TEXT,
            height_cm INTEGER,
            weight_kg INTEGER,
            date_of_birth TEXT,
            nationality TEXT,
            dominant_foot TEXT,
            photo_path TEXT,
            color_indicator TEXT,
            notes TEXT,
            is_active INTEGER DEFAULT 1,
            created_at INTEGER NOT NULL,
            modified_at INTEGER NOT NULL,
            FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE CASCADE,
            FOREIGN KEY (position_id) REFERENCES positions(position_id) ON DELETE SET NULL,
            UNIQUE(team_id, jersey_number)
        );

        -- Indexes for performance
        CREATE INDEX IF NOT EXISTS idx_sport_types_name ON sport_types(name);
        CREATE INDEX IF NOT EXISTS idx_position_groups_sport ON position_groups(sport_type_id);
        CREATE INDEX IF NOT EXISTS idx_positions_group ON positions(position_group_id);
        CREATE INDEX IF NOT EXISTS idx_teams_sport ON teams(sport_type_id);
        CREATE INDEX IF NOT EXISTS idx_players_team ON players(team_id);
        CREATE INDEX IF NOT EXISTS idx_players_position ON players(position_id);
        CREATE INDEX IF NOT EXISTS idx_players_active ON players(is_active);
        """

        var error: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, schema, nil, nil, &error) != SQLITE_OK {
            if let error = error {
                let errorMessage = String(cString: error)
                print("❌ Error creating global teams schema: \(errorMessage)")
                sqlite3_free(error)
            }
        } else {
            print("✅ Global teams schema created successfully")
            seedDefaultSportsAndPositions()
        }
    }

    private func seedDefaultSportsAndPositions() {
        guard let db = db else { return }

        // Check if we already have sports seeded
        let checkQuery = "SELECT COUNT(*) FROM sport_types"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, checkQuery, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let count = sqlite3_column_int(statement, 0)
                sqlite3_finalize(statement)
                if count > 0 {
                    print("⏭️  Default sports already seeded")
                    return
                }
            }
        }
        sqlite3_finalize(statement)

        print("🌱 Seeding default sports and positions...")

        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        // Basketball
        let basketballId = UUID().uuidString
        seedSportType(id: basketballId, name: "Basketball", timestamp: timestamp)

        let bGuardsId = UUID().uuidString
        let bForwardsId = UUID().uuidString
        let bCentersId = UUID().uuidString

        seedPositionGroup(id: bGuardsId, sportId: basketballId, name: "Guards", color: "2979ff", order: 1, timestamp: timestamp)
        seedPositionGroup(id: bForwardsId, sportId: basketballId, name: "Forwards", color: "f5c14e", order: 2, timestamp: timestamp)
        seedPositionGroup(id: bCentersId, sportId: basketballId, name: "Centers", color: "ff5252", order: 3, timestamp: timestamp)

        seedPosition(groupId: bGuardsId, code: "PG", name: "Point Guard", order: 1, timestamp: timestamp)
        seedPosition(groupId: bGuardsId, code: "SG", name: "Shooting Guard", order: 2, timestamp: timestamp)
        seedPosition(groupId: bGuardsId, code: "G", name: "Guard", order: 3, timestamp: timestamp)

        seedPosition(groupId: bForwardsId, code: "SF", name: "Small Forward", order: 1, timestamp: timestamp)
        seedPosition(groupId: bForwardsId, code: "PF", name: "Power Forward", order: 2, timestamp: timestamp)
        seedPosition(groupId: bForwardsId, code: "F", name: "Forward", order: 3, timestamp: timestamp)

        seedPosition(groupId: bCentersId, code: "C", name: "Center", order: 1, timestamp: timestamp)

        // Football/Soccer
        let footballId = UUID().uuidString
        seedSportType(id: footballId, name: "Football/Soccer", timestamp: timestamp)

        let fGoalkeepersId = UUID().uuidString
        let fDefendersId = UUID().uuidString
        let fMidfieldersId = UUID().uuidString
        let fForwardsId = UUID().uuidString

        seedPositionGroup(id: fGoalkeepersId, sportId: footballId, name: "Goalkeepers", color: "f5c14e", order: 1, timestamp: timestamp)
        seedPositionGroup(id: fDefendersId, sportId: footballId, name: "Defenders", color: "2979ff", order: 2, timestamp: timestamp)
        seedPositionGroup(id: fMidfieldersId, sportId: footballId, name: "Midfielders", color: "10b981", order: 3, timestamp: timestamp)
        seedPositionGroup(id: fForwardsId, sportId: footballId, name: "Forwards", color: "ff5252", order: 4, timestamp: timestamp)

        seedPosition(groupId: fGoalkeepersId, code: "GK", name: "Goalkeeper", order: 1, timestamp: timestamp)

        seedPosition(groupId: fDefendersId, code: "CB", name: "Center Back", order: 1, timestamp: timestamp)
        seedPosition(groupId: fDefendersId, code: "LB", name: "Left Back", order: 2, timestamp: timestamp)
        seedPosition(groupId: fDefendersId, code: "RB", name: "Right Back", order: 3, timestamp: timestamp)
        seedPosition(groupId: fDefendersId, code: "LWB", name: "Left Wing Back", order: 4, timestamp: timestamp)
        seedPosition(groupId: fDefendersId, code: "RWB", name: "Right Wing Back", order: 5, timestamp: timestamp)

        seedPosition(groupId: fMidfieldersId, code: "CM", name: "Central Midfielder", order: 1, timestamp: timestamp)
        seedPosition(groupId: fMidfieldersId, code: "CDM", name: "Defensive Midfielder", order: 2, timestamp: timestamp)
        seedPosition(groupId: fMidfieldersId, code: "CAM", name: "Attacking Midfielder", order: 3, timestamp: timestamp)
        seedPosition(groupId: fMidfieldersId, code: "LM", name: "Left Midfielder", order: 4, timestamp: timestamp)
        seedPosition(groupId: fMidfieldersId, code: "RM", name: "Right Midfielder", order: 5, timestamp: timestamp)

        seedPosition(groupId: fForwardsId, code: "CF", name: "Center Forward", order: 1, timestamp: timestamp)
        seedPosition(groupId: fForwardsId, code: "ST", name: "Striker", order: 2, timestamp: timestamp)
        seedPosition(groupId: fForwardsId, code: "LW", name: "Left Winger", order: 3, timestamp: timestamp)
        seedPosition(groupId: fForwardsId, code: "RW", name: "Right Winger", order: 4, timestamp: timestamp)

        print("✅ Default sports and positions seeded successfully")
    }

    private func seedSportType(id: String, name: String, timestamp: Int64) {
        guard let db = db else { return }
        let query = "INSERT OR IGNORE INTO sport_types (sport_type_id, name, created_at) VALUES (?, ?, ?)"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            id.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
            name.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
            sqlite3_bind_int64(statement, 3, timestamp)
            sqlite3_step(statement)
        }
    }

    private func seedPositionGroup(id: String, sportId: String, name: String, color: String, order: Int, timestamp: Int64) {
        guard let db = db else { return }
        let query = "INSERT OR IGNORE INTO position_groups (position_group_id, sport_type_id, name, color, display_order, created_at) VALUES (?, ?, ?, ?, ?, ?)"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            id.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
            sportId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
            name.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
            color.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
            sqlite3_bind_int(statement, 5, Int32(order))
            sqlite3_bind_int64(statement, 6, timestamp)
            sqlite3_step(statement)
        }
    }

    private func seedPosition(groupId: String, code: String, name: String, order: Int, timestamp: Int64) {
        guard let db = db else { return }
        let query = "INSERT OR IGNORE INTO positions (position_id, position_group_id, code, name, display_order, created_at) VALUES (?, ?, ?, ?, ?, ?)"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            let positionId = UUID().uuidString
            positionId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
            groupId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
            code.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
            name.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
            sqlite3_bind_int(statement, 5, Int32(order))
            sqlite3_bind_int64(statement, 6, timestamp)
            sqlite3_step(statement)
        }
    }

    // MARK: - Sport Type CRUD

    func getSportTypes() -> [SportType] {
        guard let db = db else { return [] }

        let query = "SELECT sport_type_id, name, created_at FROM sport_types ORDER BY name ASC"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        var sportTypes: [SportType] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let name = String(cString: sqlite3_column_text(statement, 1))
            let createdAt = Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 2)) / 1000.0)

            sportTypes.append(SportType(id: id, name: name, createdAt: createdAt))
        }

        return sportTypes
    }

    // MARK: - Position Group CRUD

    func getPositionGroups(sportTypeId: String) -> [PositionGroup] {
        guard let db = db else { return [] }

        let query = """
            SELECT position_group_id, sport_type_id, name, color, display_order
            FROM position_groups
            WHERE sport_type_id = ?
            ORDER BY display_order ASC
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sportTypeId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var positionGroups: [PositionGroup] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let sportId = String(cString: sqlite3_column_text(statement, 1))
            let name = String(cString: sqlite3_column_text(statement, 2))
            let color = String(cString: sqlite3_column_text(statement, 3))
            let displayOrder = Int(sqlite3_column_int(statement, 4))

            positionGroups.append(PositionGroup(id: id, sportTypeId: sportId, name: name, color: color, displayOrder: displayOrder))
        }

        return positionGroups
    }

    func createPositionGroup(sportTypeId: String, name: String, color: String, displayOrder: Int) -> Result<String, Error> {
        guard let db = db else {
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not available"]))
        }

        let groupId = UUID().uuidString
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        let query = "INSERT INTO position_groups (position_group_id, sport_type_id, name, color, display_order, created_at) VALUES (?, ?, ?, ?, ?, ?)"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        groupId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        sportTypeId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        name.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        color.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int(statement, 5, Int32(displayOrder))
        sqlite3_bind_int64(statement, 6, timestamp)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        return .success(groupId)
    }

    // MARK: - Position CRUD

    func getPositions(positionGroupId: String) -> [Position] {
        guard let db = db else { return [] }

        let query = """
            SELECT position_id, position_group_id, code, name, display_order
            FROM positions
            WHERE position_group_id = ?
            ORDER BY display_order ASC
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        positionGroupId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var positions: [Position] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let groupId = String(cString: sqlite3_column_text(statement, 1))
            let code = String(cString: sqlite3_column_text(statement, 2))
            let name = String(cString: sqlite3_column_text(statement, 3))
            let displayOrder = Int(sqlite3_column_int(statement, 4))

            positions.append(Position(id: id, positionGroupId: groupId, code: code, name: name, displayOrder: displayOrder))
        }

        return positions
    }

    func getAllPositionsForSport(sportTypeId: String) -> [Position] {
        guard let db = db else { return [] }

        let query = """
            SELECT p.position_id, p.position_group_id, p.code, p.name, p.display_order
            FROM positions p
            JOIN position_groups pg ON p.position_group_id = pg.position_group_id
            WHERE pg.sport_type_id = ?
            ORDER BY pg.display_order ASC, p.display_order ASC
        """
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sportTypeId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var positions: [Position] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let groupId = String(cString: sqlite3_column_text(statement, 1))
            let code = String(cString: sqlite3_column_text(statement, 2))
            let name = String(cString: sqlite3_column_text(statement, 3))
            let displayOrder = Int(sqlite3_column_int(statement, 4))

            positions.append(Position(id: id, positionGroupId: groupId, code: code, name: name, displayOrder: displayOrder))
        }

        return positions
    }

    func createPosition(positionGroupId: String, code: String, name: String, displayOrder: Int) -> Result<String, Error> {
        guard let db = db else {
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not available"]))
        }

        let positionId = UUID().uuidString
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        let query = "INSERT INTO positions (position_id, position_group_id, code, name, display_order, created_at) VALUES (?, ?, ?, ?, ?, ?)"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        positionId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        positionGroupId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        code.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        name.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int(statement, 5, Int32(displayOrder))
        sqlite3_bind_int64(statement, 6, timestamp)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        return .success(positionId)
    }

    // MARK: - Team CRUD

    func createTeam(name: String, shortName: String?, organization: String?, sportTypeId: String, primaryColor: String = "#2979ff") -> Result<String, Error> {
        guard let db = db else {
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not available"]))
        }

        let teamId = UUID().uuidString
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        let query = """
            INSERT INTO teams (team_id, name, short_name, organization, sport_type_id, primary_color, created_at, modified_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        teamId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        name.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        shortName?.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 3)
        organization?.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 4)
        sportTypeId.withCString { sqlite3_bind_text(statement, 5, $0, -1, SQLITE_TRANSIENT) }
        primaryColor.withCString { sqlite3_bind_text(statement, 6, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int64(statement, 7, timestamp)
        sqlite3_bind_int64(statement, 8, timestamp)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        print("✅ Created team: \(name) (ID: \(teamId))")
        return .success(teamId)
    }

    func getTeams() -> [Team] {
        guard let db = db else {
            print("❌ getTeams: Database not initialized")
            return []
        }

        let query = """
            SELECT team_id, name, short_name, organization, sport_type_id, primary_color
            FROM teams
            ORDER BY name ASC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ getTeams: Failed to prepare query - \(errorMessage)")
            print("   Query: \(query)")
            return []
        }

        var teams: [Team] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let teamId = String(cString: sqlite3_column_text(statement, 0))
            let name = String(cString: sqlite3_column_text(statement, 1))
            let shortName = sqlite3_column_type(statement, 2) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 2))
                : nil
            let organization = sqlite3_column_type(statement, 3) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 3))
                : nil
            let sportTypeId = String(cString: sqlite3_column_text(statement, 4))
            let primaryColor = String(cString: sqlite3_column_text(statement, 5))

            let team = Team(
                id: teamId,
                name: name,
                shortName: shortName,
                organization: organization,
                sportTypeId: sportTypeId,
                primaryColor: primaryColor
            )
            teams.append(team)
        }

        print("✅ getTeams: Loaded \(teams.count) teams from database")
        return teams
    }

    // MARK: - Player CRUD

    func createPlayer(
        teamId: String,
        firstName: String,
        lastName: String,
        jerseyNumber: Int,
        positionId: String?,
        heightCm: Int?,
        weightKg: Int?,
        dateOfBirth: String?,
        nationality: String?,
        dominantFoot: String?,
        colorIndicator: String?,
        notes: String?
    ) -> Result<String, Error> {
        guard let db = db else {
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not available"]))
        }

        let playerId = UUID().uuidString
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        let query = """
            INSERT INTO players (
                player_id, team_id, first_name, last_name, jersey_number, position_id,
                height_cm, weight_kg, date_of_birth, nationality, dominant_foot, color_indicator,
                notes, is_active, created_at, modified_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        playerId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        teamId.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        firstName.withCString { sqlite3_bind_text(statement, 3, $0, -1, SQLITE_TRANSIENT) }
        lastName.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int(statement, 5, Int32(jerseyNumber))
        positionId?.withCString { sqlite3_bind_text(statement, 6, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 6)

        if let height = heightCm {
            sqlite3_bind_int(statement, 7, Int32(height))
        } else {
            sqlite3_bind_null(statement, 7)
        }

        if let weight = weightKg {
            sqlite3_bind_int(statement, 8, Int32(weight))
        } else {
            sqlite3_bind_null(statement, 8)
        }

        dateOfBirth?.withCString { sqlite3_bind_text(statement, 9, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 9)
        nationality?.withCString { sqlite3_bind_text(statement, 10, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 10)
        dominantFoot?.withCString { sqlite3_bind_text(statement, 11, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 11)
        colorIndicator?.withCString { sqlite3_bind_text(statement, 12, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 12)
        notes?.withCString { sqlite3_bind_text(statement, 13, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 13)

        sqlite3_bind_int64(statement, 14, timestamp)
        sqlite3_bind_int64(statement, 15, timestamp)

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        print("✅ Created player: \(firstName) \(lastName) #\(jerseyNumber)")
        return .success(playerId)
    }

    func updatePlayer(
        playerId: String,
        firstName: String,
        lastName: String,
        jerseyNumber: Int,
        positionId: String?,
        heightCm: Int?,
        weightKg: Int?,
        dateOfBirth: String?,
        nationality: String?,
        dominantFoot: String?,
        colorIndicator: String?,
        notes: String?
    ) -> Result<Void, Error> {
        guard let db = db else {
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not available"]))
        }

        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)

        let query = """
            UPDATE players
            SET first_name = ?, last_name = ?, jersey_number = ?, position_id = ?,
                height_cm = ?, weight_kg = ?, date_of_birth = ?, nationality = ?, dominant_foot = ?,
                color_indicator = ?, notes = ?, modified_at = ?
            WHERE player_id = ?
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        firstName.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }
        lastName.withCString { sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT) }
        sqlite3_bind_int(statement, 3, Int32(jerseyNumber))
        positionId?.withCString { sqlite3_bind_text(statement, 4, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 4)

        if let height = heightCm {
            sqlite3_bind_int(statement, 5, Int32(height))
        } else {
            sqlite3_bind_null(statement, 5)
        }

        if let weight = weightKg {
            sqlite3_bind_int(statement, 6, Int32(weight))
        } else {
            sqlite3_bind_null(statement, 6)
        }

        dateOfBirth?.withCString { sqlite3_bind_text(statement, 7, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 7)
        nationality?.withCString { sqlite3_bind_text(statement, 8, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 8)
        dominantFoot?.withCString { sqlite3_bind_text(statement, 9, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 9)
        colorIndicator?.withCString { sqlite3_bind_text(statement, 10, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 10)
        notes?.withCString { sqlite3_bind_text(statement, 11, $0, -1, SQLITE_TRANSIENT) } ?? sqlite3_bind_null(statement, 11)

        sqlite3_bind_int64(statement, 12, timestamp)
        playerId.withCString { sqlite3_bind_text(statement, 13, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        print("✅ Updated player: \(firstName) \(lastName) #\(jerseyNumber)")
        return .success(())
    }

    /// Get all players that have notes (across all teams)
    func getAllPlayersWithNotes() -> [PlayerInfo] {
        guard let db = db else { return [] }

        let query = """
            SELECT
                p.player_id, p.team_id, p.first_name, p.last_name, p.jersey_number,
                p.height_cm, p.weight_kg, p.date_of_birth, p.nationality, p.dominant_foot,
                p.photo_path, p.color_indicator, p.notes,
                pos.position_id, pos.code, pos.name, pos.display_order,
                pg.position_group_id, pg.name as group_name, pg.color, pg.display_order
            FROM players p
            LEFT JOIN positions pos ON p.position_id = pos.position_id
            LEFT JOIN position_groups pg ON pos.position_group_id = pg.position_group_id
            WHERE p.is_active = 1 AND p.notes IS NOT NULL AND LENGTH(p.notes) > 0
            ORDER BY p.last_name ASC, p.first_name ASC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        var players: [PlayerInfo] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let playerId = String(cString: sqlite3_column_text(statement, 0))
            let teamId = String(cString: sqlite3_column_text(statement, 1))
            let firstName = String(cString: sqlite3_column_text(statement, 2))
            let lastName = String(cString: sqlite3_column_text(statement, 3))
            let jerseyNumber = Int(sqlite3_column_int(statement, 4))

            let heightCm = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? Int(sqlite3_column_int(statement, 5))
                : nil
            let weightKg = sqlite3_column_type(statement, 6) != SQLITE_NULL
                ? Int(sqlite3_column_int(statement, 6))
                : nil
            let dateOfBirth = sqlite3_column_type(statement, 7) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 7))
                : nil
            let nationality = sqlite3_column_type(statement, 8) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 8))
                : nil
            let dominantFoot = sqlite3_column_type(statement, 9) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 9))
                : nil
            let photoPath = sqlite3_column_type(statement, 10) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 10))
                : nil
            let colorIndicator = sqlite3_column_type(statement, 11) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 11))
                : nil
            let notes = sqlite3_column_type(statement, 12) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 12))
                : nil

            // Position info
            var position: Position? = nil
            var positionGroupId = ""
            if sqlite3_column_type(statement, 13) != SQLITE_NULL {
                let posId = String(cString: sqlite3_column_text(statement, 13))
                let posCode = String(cString: sqlite3_column_text(statement, 14))
                let posName = String(cString: sqlite3_column_text(statement, 15))
                let posOrder = Int(sqlite3_column_int(statement, 16))
                // Get position group ID from column 17
                if sqlite3_column_type(statement, 17) != SQLITE_NULL {
                    positionGroupId = String(cString: sqlite3_column_text(statement, 17))
                }
                position = Position(id: posId, positionGroupId: positionGroupId, code: posCode, name: posName, displayOrder: posOrder)
            }

            // Position group info
            var positionGroup: PositionGroup? = nil
            if sqlite3_column_type(statement, 17) != SQLITE_NULL {
                let pgId = String(cString: sqlite3_column_text(statement, 17))
                let pgName = String(cString: sqlite3_column_text(statement, 18))
                let pgColor = String(cString: sqlite3_column_text(statement, 19))
                let pgOrder = Int(sqlite3_column_int(statement, 20))
                positionGroup = PositionGroup(id: pgId, sportTypeId: "", name: pgName, color: pgColor, displayOrder: pgOrder)
            }

            let player = PlayerInfo(
                id: playerId,
                teamId: teamId,
                firstName: firstName,
                lastName: lastName,
                jerseyNumber: jerseyNumber,
                position: position,
                positionGroup: positionGroup,
                heightCm: heightCm,
                weightKg: weightKg,
                dateOfBirth: dateOfBirth,
                nationality: nationality,
                dominantFoot: dominantFoot,
                photoPath: photoPath,
                colorIndicator: colorIndicator,
                notes: notes
            )
            players.append(player)
        }

        return players
    }

    func getPlayers(teamId: String) -> [PlayerInfo] {
        guard let db = db else { return [] }

        let query = """
            SELECT
                p.player_id, p.first_name, p.last_name, p.jersey_number,
                p.height_cm, p.weight_kg, p.date_of_birth, p.nationality, p.dominant_foot,
                p.photo_path, p.color_indicator, p.notes,
                pos.position_id, pos.code, pos.name, pos.display_order,
                pg.position_group_id, pg.name as group_name, pg.color, pg.display_order
            FROM players p
            LEFT JOIN positions pos ON p.position_id = pos.position_id
            LEFT JOIN position_groups pg ON pos.position_group_id = pg.position_group_id
            WHERE p.team_id = ? AND p.is_active = 1
            ORDER BY p.jersey_number ASC
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        teamId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        var players: [PlayerInfo] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let playerId = String(cString: sqlite3_column_text(statement, 0))
            let firstName = String(cString: sqlite3_column_text(statement, 1))
            let lastName = String(cString: sqlite3_column_text(statement, 2))
            let jerseyNumber = Int(sqlite3_column_int(statement, 3))

            let heightCm = sqlite3_column_type(statement, 4) != SQLITE_NULL
                ? Int(sqlite3_column_int(statement, 4))
                : nil
            let weightKg = sqlite3_column_type(statement, 5) != SQLITE_NULL
                ? Int(sqlite3_column_int(statement, 5))
                : nil
            let dateOfBirth = sqlite3_column_type(statement, 6) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 6))
                : nil
            let nationality = sqlite3_column_type(statement, 7) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 7))
                : nil
            let dominantFoot = sqlite3_column_type(statement, 8) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 8))
                : nil
            let photoPath = sqlite3_column_type(statement, 9) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 9))
                : nil
            let colorIndicator = sqlite3_column_type(statement, 10) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 10))
                : nil
            let notes = sqlite3_column_type(statement, 11) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(statement, 11))
                : nil

            // Parse Position
            var position: Position? = nil
            if sqlite3_column_type(statement, 12) != SQLITE_NULL {
                let posId = String(cString: sqlite3_column_text(statement, 12))
                let posCode = String(cString: sqlite3_column_text(statement, 13))
                let posName = String(cString: sqlite3_column_text(statement, 14))
                let posOrder = Int(sqlite3_column_int(statement, 15))

                // Get position group id
                let posGroupId = sqlite3_column_type(statement, 16) != SQLITE_NULL
                    ? String(cString: sqlite3_column_text(statement, 16))
                    : ""

                position = Position(id: posId, positionGroupId: posGroupId, code: posCode, name: posName, displayOrder: posOrder)
            }

            // Parse Position Group
            var positionGroup: PositionGroup? = nil
            if sqlite3_column_type(statement, 16) != SQLITE_NULL {
                let pgId = String(cString: sqlite3_column_text(statement, 16))
                let pgName = String(cString: sqlite3_column_text(statement, 17))
                let pgColor = String(cString: sqlite3_column_text(statement, 18))
                let pgOrder = Int(sqlite3_column_int(statement, 19))

                // We need sport_type_id - let's get it from position.positionGroupId context
                // For now use empty string, we'll query it if needed
                positionGroup = PositionGroup(id: pgId, sportTypeId: "", name: pgName, color: pgColor, displayOrder: pgOrder)
            }

            let player = PlayerInfo(
                id: playerId,
                teamId: teamId,
                firstName: firstName,
                lastName: lastName,
                jerseyNumber: jerseyNumber,
                position: position,
                positionGroup: positionGroup,
                heightCm: heightCm,
                weightKg: weightKg,
                dateOfBirth: dateOfBirth,
                nationality: nationality,
                dominantFoot: dominantFoot,
                photoPath: photoPath,
                colorIndicator: colorIndicator,
                notes: notes
            )
            players.append(player)
        }

        return players
    }

    func deletePlayer(playerId: String) -> Result<Void, Error> {
        guard let db = db else {
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not available"]))
        }

        // Soft delete (set is_active = 0)
        let query = "UPDATE players SET is_active = 0 WHERE player_id = ?"

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        playerId.withCString { sqlite3_bind_text(statement, 1, $0, -1, SQLITE_TRANSIENT) }

        if sqlite3_step(statement) != SQLITE_DONE {
            let error = String(cString: sqlite3_errmsg(db))
            return .failure(NSError(domain: "GlobalTeamsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
        }

        return .success(())
    }
}

// MARK: - Models

struct SportType: Identifiable {
    let id: String
    let name: String
    let createdAt: Date
}

struct PositionGroup: Identifiable {
    let id: String
    let sportTypeId: String
    let name: String
    let color: String
    let displayOrder: Int
}

struct Position: Identifiable {
    let id: String
    let positionGroupId: String
    let code: String
    let name: String
    let displayOrder: Int
}

struct Team: Identifiable {
    let id: String
    let name: String
    let shortName: String?
    let organization: String?
    let sportTypeId: String
    let primaryColor: String
}

struct PlayerInfo: Identifiable {
    let id: String
    let teamId: String
    let firstName: String
    let lastName: String
    let jerseyNumber: Int
    let position: Position?
    let positionGroup: PositionGroup?
    let heightCm: Int?
    let weightKg: Int?
    let dateOfBirth: String?
    let nationality: String?
    let dominantFoot: String?
    let photoPath: String?
    let colorIndicator: String?
    let notes: String?

    var fullName: String {
        "\(firstName) \(lastName)"
    }

    var positionCode: String {
        position?.code ?? "—"
    }

    var positionGroupName: String {
        positionGroup?.name ?? "—"
    }

    var heightWeight: String {
        var parts: [String] = []
        if let height = heightCm {
            parts.append("\(height) cm")
        }
        if let weight = weightKg {
            parts.append("\(weight) kg")
        }
        return parts.joined(separator: " / ")
    }
}

