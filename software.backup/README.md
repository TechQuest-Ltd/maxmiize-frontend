# Maxmiize Sports Analysis Platform

**Version:** 1.0  
**Platform:** macOS  
**Focus:** Basketball Analysis

---

## Overview

Maxmiize is a professional-grade macOS desktop application for basketball video analysis. It enables coaches, analysts, and teams to capture, analyze, and present game footage with an intuitive interface designed specifically for basketball workflows.

### Mission

Provide basketball coaches and analysts with a powerful, intuitive, and offline-first video analysis tool that streamlines game breakdown, player development, and opponent scouting.

---

## Core Features

### Video Management
- Multi-angle capture (4+ simultaneous cameras)
- HDMI/USB camera input support
- Import various formats (MP4, MOV, H.264, H.265, ProRes)
- Frame-accurate playback with variable speed (0.25x - 6x)
- Multi-angle viewing (single, dual, quad layouts)

### Basketball Tagging System
- Pre-built basketball event templates
- Customizable hotkey configuration
- Real-time and post-game tagging
- Player-specific tracking
- Tag editing and deletion

### Annotation Tools
- Line, Arrow, Circle/Ellipse, Text, Spotlight tools
- Court overlay templates (half-court and full-court)
- Freehand drawing and polygon tools (PRO)
- Color picker and line thickness controls
- 50-step undo/redo system

### Playlist Management
- Create playlists from tagged possessions
- Drag-and-drop clip organization
- Advanced filtering (player, event type, outcome, quarter, etc.)
- Export as MP4 video

### Presentation Builder (PRO)
- Film room presentation mode
- Split-screen and picture-in-picture layouts
- Text overlays and transition effects
- Screen-record with voice-over feature
- Import external clips (YouTube/Instagram)

### Statistical Analysis
- Automatic statistics from tags
- Shot charts with heat maps
- Player performance tracking
- Team efficiency metrics
- Export to CSV/Excel

---

## Technology Stack

- **Swift & SwiftUI** - Native macOS development
- **C++** - High-performance video processing
- **Metal** - Hardware-accelerated graphics
- **SQLite** - Embedded database
- **AVFoundation** - Video framework

---

## Project Structure

```
maxmiize-v1/
├── Sources/              # Swift source code
│   ├── App/              # Application entry point
│   ├── Core/             # Business logic
│   ├── Features/         # Feature modules
│   ├── UI/               # SwiftUI views and components
│   └── Utils/            # Utilities and extensions
├── Database/             # SQL schema and seeds
├── Scripts/              # Build scripts
└── maxmiize-v1.xcodeproj/
```

---

## Database

**Type:** SQLite 3  
**Tables:** 23 tables with 45 performance indexes  
**Location:** `/Database/schema.sql`

### Key Tables
- Projects, Teams, Players, Games
- Videos, Video Sync, Tags
- Annotations, Playlists
- Statistics, Shot Charts

---

## Development Setup

### Prerequisites
```bash
# Install Xcode 15.0+
xcode-select --install
```

### Database Setup
```bash
# Run setup script
./Scripts/setup_database.sh

# Or manually
cd Database
sqlite3 maxmiize_dev.db < schema.sql
sqlite3 maxmiize_dev.db < seeds/default_templates.sql
```

### Building from Source
```bash
# Clone repository
git clone https://github.com/maxmiize/maxmiize-v1.git
cd maxmiize-v1

# Open in Xcode
open maxmiize-v1.xcodeproj

# Build and run (⌘ + R)
```

---

## System Requirements

### Minimum
- macOS 12.0 (Monterey) or later
- Apple Silicon (M1+) or Intel i5 (8th gen+)
- 8GB RAM
- 50GB storage
- GPU with Metal support

### Recommended (PRO with 4K)
- macOS 13.0 (Ventura) or later
- Apple Silicon (M1 Pro/Max/Ultra or M2+)
- 16GB RAM
- 500GB SSD storage

---

## Performance Targets

| Metric       | Target                       |
| ------------ | ---------------------------- |
| Launch Time  | <2 seconds                   |
| Seek Latency | <200ms (MVP), <100ms (PRO)   |
| Frame Rate   | 60fps                        |
| Multi-Angle  | 4x 1080p@60fps               |
| 4K Support   | 2x 4K@30fps (PRO)            |
| Auto-Save    | Every 30 seconds             |

---

## Development Roadmap

### Phase 1: MVP - "Pro Coach Essentials" (6 Weeks) ✅
- Core video engine and playback
- Basketball tagging system
- Annotation tools
- Playlist management
- Sportscode/Catapult import/export

### Phase 2: PRO - "Team Workflow & Advanced Features" (2 Weeks) ✅
- 4K video support
- Advanced annotation tools
- Roster management
- Presentation builder
- Screen-record with voice-over

### Phase 3: ELITE - "AI & Cloud Integration" (Future)
- AI-assisted event detection
- Player tracking
- Cloud collaboration
- Mobile companion app

---

## License & Pricing

### Subscription Tiers

**MVP - "Pro Coach Essentials"**
- 6-month: $299 | 12-month: $499
- All core analysis features

**PRO - "Team Workflow & Advanced"**
- 6-month: $599 | 12-month: $999
- 4K support, advanced features, presentation tools

**ELITE - "AI & Cloud Integration"** (Future)
- 6-month: $999 | 12-month: $1,699
- AI analysis, cloud collaboration, mobile app

---

## Quick Start Guide

### Creating Your First Project
1. New Project → Name it (e.g., "2024-25 Season")
2. Add Team Roster → Enter player names and numbers
3. Create Game → Add opponent info and date
4. Import Video or Start Live Capture

### Tagging a Game
1. Load video in timeline
2. Select tagging template
3. Use hotkeys to tag events:
   - `3` = Three-point shot
   - `M` = Made
   - `2` `3` = Player #23
4. Review possessions using timeline markers

### Creating a Playlist
1. Playlists → New Playlist
2. Filter by criteria (Player, Event Type, Outcome, Quarter)
3. Drag additional clips from timeline
4. Export as MP4 for film session

---

## Support & Resources

**Website:** maxmiize.com  
**Documentation:** maxmiize.com/docs  
**Support Email:** support@maxmiize.com

---

## Contributing

1. Create feature branch from `main`
2. Follow Swift style guide
3. Write unit tests for new features
4. Submit pull request with detailed description
5. Code review required before merge

---

**Version 1.0** | © Maxmiize Sports Analysis Platform

_Professional basketball video analysis, redefined._
