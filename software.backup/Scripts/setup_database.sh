#!/bin/bash

# Maxmiize Database Setup Script
# Creates a local development database with schema and seed data

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DATABASE_DIR="$PROJECT_ROOT/Database"
DB_FILE="$DATABASE_DIR/maxmiize_dev.db"

echo "🏀 Maxmiize Database Setup"
echo "=========================="
echo ""

# Check if SQLite is available
if ! command -v sqlite3 &> /dev/null; then
    echo "❌ Error: sqlite3 not found in PATH"
    echo "   SQLite should be installed on macOS by default."
    echo "   Try: /usr/bin/sqlite3 --version"
    exit 1
fi

echo "✅ SQLite found: $(sqlite3 --version)"
echo ""

# Create database directory if it doesn't exist
mkdir -p "$DATABASE_DIR"

# Remove existing dev database if it exists
if [ -f "$DB_FILE" ]; then
    echo "⚠️  Existing dev database found. Removing..."
    rm "$DB_FILE"
fi

echo "📊 Creating database schema..."
sqlite3 "$DB_FILE" < "$DATABASE_DIR/schema.sql"

if [ $? -eq 0 ]; then
    echo "✅ Schema created successfully"
else
    echo "❌ Error creating schema"
    exit 1
fi

echo ""
echo "🌱 Loading seed data..."
sqlite3 "$DB_FILE" < "$DATABASE_DIR/seeds/default_templates.sql"

if [ $? -eq 0 ]; then
    echo "✅ Seed data loaded successfully"
else
    echo "❌ Error loading seed data"
    exit 1
fi

echo ""
echo "🔍 Verifying database..."

# Count tables
TABLE_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
echo "   Tables created: $TABLE_COUNT"

# Count templates
TEMPLATE_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tagging_templates;")
echo "   Tagging templates: $TEMPLATE_COUNT"

# Count annotation templates
ANNOTATION_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM annotation_templates;")
echo "   Annotation templates: $ANNOTATION_COUNT"

echo ""
echo "✅ Database setup complete!"
echo ""
echo "📁 Database location: $DB_FILE"
echo ""
echo "💡 To inspect the database:"
echo "   sqlite3 $DB_FILE"
echo ""
echo "💡 To view tables:"
echo "   sqlite3 $DB_FILE \".tables\""
echo ""
echo "💡 To view schema:"
echo "   sqlite3 $DB_FILE \".schema\""
echo ""

