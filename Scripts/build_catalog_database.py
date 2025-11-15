#!/usr/bin/env python3
"""
Build catalog SQLite database from JSON sources.

This script reads JSON files for glass items, coatings, and tools,
and creates a single SQLite database that can be bundled with the app.

Usage:
    python3 Scripts/build_catalog_database.py

Output:
    Molten/Sources/Resources/catalog.sqlite
"""

import sqlite3
import json
import os
import sys
from datetime import datetime
from pathlib import Path

# Define paths relative to script location
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
RESOURCES_DIR = PROJECT_ROOT / "Molten" / "Sources" / "Resources"
TOOLS_DIR = PROJECT_ROOT / "Molten" / "Data" / "Tools"

# Input JSON files
GLASS_JSON = RESOURCES_DIR / "glass_catalog.json"
COATINGS_JSON = RESOURCES_DIR / "coatings.json"
TOOLS_JSON = TOOLS_DIR / "tools.json"

# Output SQLite database
OUTPUT_DB = RESOURCES_DIR / "catalog.sqlite"

# Database version (auto-incremented on each build)
# Note: This is just a fallback - the actual version is read from existing DB and incremented
DB_VERSION_FALLBACK = 1


def create_schema(conn):
    """Create database schema."""
    cursor = conn.cursor()

    # Metadata table - stores database version
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
    """)

    # Glass items table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS glass_items (
            stable_id TEXT PRIMARY KEY,
            status TEXT NOT NULL,
            added_date TEXT,
            last_seen TEXT,
            discontinued_date TEXT,
            manufacturer TEXT NOT NULL,
            code TEXT NOT NULL,
            name TEXT NOT NULL,
            start_date TEXT,
            end_date TEXT,
            manufacturer_description TEXT,
            tags TEXT,
            synonyms TEXT,
            coe TEXT,
            type TEXT,
            manufacturer_url TEXT,
            image_path TEXT,
            image_url TEXT,
            stock_type TEXT
        )
    """)

    # Create indexes for common queries
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_glass_manufacturer ON glass_items(manufacturer)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_glass_status ON glass_items(status)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_glass_coe ON glass_items(coe)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_glass_type ON glass_items(type)")

    # Coatings table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS coatings (
            stable_id TEXT PRIMARY KEY,
            code TEXT NOT NULL,
            name TEXT NOT NULL,
            manufacturer TEXT NOT NULL,
            manufacturer_description TEXT,
            tags TEXT,
            image_url TEXT,
            image_path TEXT,
            manufacturer_url TEXT,
            product_type TEXT,
            coe TEXT
        )
    """)

    cursor.execute("CREATE INDEX IF NOT EXISTS idx_coating_manufacturer ON coatings(manufacturer)")

    # Tools table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS tools (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            sku TEXT NOT NULL,
            description TEXT,
            price REAL,
            category TEXT,
            image_url TEXT,
            product_url TEXT,
            status TEXT,
            manufacturer TEXT NOT NULL,
            UNIQUE(manufacturer, sku)
        )
    """)

    cursor.execute("CREATE INDEX IF NOT EXISTS idx_tool_manufacturer ON tools(manufacturer)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_tool_category ON tools(category)")
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_tool_status ON tools(status)")

    conn.commit()


def import_glass_items(conn, json_file):
    """Import glass items from JSON."""
    print(f"📦 Loading glass items from {json_file}...")

    with open(json_file, 'r') as f:
        data = json.load(f)

    cursor = conn.cursor()
    items = data.get('glassitems', [])

    for item in items:
        cursor.execute("""
            INSERT OR REPLACE INTO glass_items (
                stable_id, status, added_date, last_seen, discontinued_date,
                manufacturer, code, name, start_date, end_date,
                manufacturer_description, tags, synonyms, coe, type,
                manufacturer_url, image_path, image_url, stock_type
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            item['stable_id'],
            item['status'],
            item.get('added_date'),
            item.get('last_seen'),
            item.get('discontinued_date'),
            item['manufacturer'],
            item['code'],
            item['name'],
            item.get('start_date'),
            item.get('end_date'),
            item.get('manufacturer_description'),
            json.dumps(item.get('tags', [])),
            json.dumps(item.get('synonyms', [])),
            item.get('coe'),
            item.get('type'),
            item.get('manufacturer_url'),
            item.get('image_path'),
            item.get('image_url'),
            item.get('stock_type')
        ))

    conn.commit()
    print(f"✅ Imported {len(items)} glass items")
    return len(items)


def import_coatings(conn, json_file):
    """Import coatings from JSON."""
    print(f"📦 Loading coatings from {json_file}...")

    with open(json_file, 'r') as f:
        data = json.load(f)

    cursor = conn.cursor()
    items = data.get('coatings', [])

    for item in items:
        cursor.execute("""
            INSERT OR REPLACE INTO coatings (
                stable_id, code, name, manufacturer, manufacturer_description,
                tags, image_url, image_path, manufacturer_url, product_type, coe
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            item['stable_id'],
            item['code'],
            item['name'],
            item['manufacturer'],
            item.get('manufacturer_description'),
            item.get('tags'),  # Already a string in the JSON
            item.get('image_url'),
            item.get('image_path'),
            item.get('manufacturer_url'),
            item.get('product_type'),
            item.get('coe')
        ))

    conn.commit()
    print(f"✅ Imported {len(items)} coatings")
    return len(items)


def import_tools(conn, json_file):
    """Import tools from JSON."""
    print(f"📦 Loading tools from {json_file}...")

    with open(json_file, 'r') as f:
        data = json.load(f)

    cursor = conn.cursor()
    items = data.get('tools', [])

    for item in items:
        cursor.execute("""
            INSERT OR REPLACE INTO tools (
                name, sku, description, price, category,
                image_url, product_url, status, manufacturer
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            item['name'],
            item['sku'],
            item.get('description'),
            item.get('price'),
            item.get('category'),
            item.get('image_url'),
            item.get('product_url'),
            item.get('status'),
            item['manufacturer']
        ))

    conn.commit()
    print(f"✅ Imported {len(items)} tools")
    return len(items)


def set_metadata(conn, version, item_counts):
    """Set database metadata."""
    cursor = conn.cursor()

    cursor.execute("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)",
                  ('version', str(version)))
    cursor.execute("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)",
                  ('last_updated', datetime.now().isoformat()))
    cursor.execute("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)",
                  ('glass_items_count', str(item_counts['glass'])))
    cursor.execute("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)",
                  ('coatings_count', str(item_counts['coatings'])))
    cursor.execute("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)",
                  ('tools_count', str(item_counts['tools'])))

    conn.commit()


def get_current_version() -> int:
    """Get version from existing database, or return fallback if doesn't exist."""
    if not OUTPUT_DB.exists():
        return DB_VERSION_FALLBACK

    try:
        conn = sqlite3.connect(str(OUTPUT_DB))
        cursor = conn.cursor()
        cursor.execute("SELECT value FROM metadata WHERE key = 'version'")
        result = cursor.fetchone()
        conn.close()

        if result:
            return int(result[0])
        else:
            return DB_VERSION_FALLBACK
    except:
        return DB_VERSION_FALLBACK


def main():
    """Main entry point."""
    print("🔨 Building catalog database...")

    # Auto-increment version from existing database
    current_version = get_current_version()
    new_version = current_version + 1

    print(f"   Current version: {current_version}")
    print(f"   New version: {new_version}")
    print(f"   Output: {OUTPUT_DB}")
    print()

    # Verify input files exist
    missing_files = []
    if not GLASS_JSON.exists():
        missing_files.append(str(GLASS_JSON))
    if not COATINGS_JSON.exists():
        missing_files.append(str(COATINGS_JSON))
    if not TOOLS_JSON.exists():
        missing_files.append(str(TOOLS_JSON))

    if missing_files:
        print("❌ Missing input files:")
        for f in missing_files:
            print(f"   - {f}")
        sys.exit(1)

    # Remove existing database
    if OUTPUT_DB.exists():
        OUTPUT_DB.unlink()
        print(f"🗑️  Removed existing database")

    # Create database and schema
    conn = sqlite3.connect(str(OUTPUT_DB))
    create_schema(conn)
    print("✅ Created database schema")
    print()

    # Import data
    item_counts = {}
    item_counts['glass'] = import_glass_items(conn, GLASS_JSON)
    item_counts['coatings'] = import_coatings(conn, COATINGS_JSON)
    item_counts['tools'] = import_tools(conn, TOOLS_JSON)

    # Set metadata
    set_metadata(conn, new_version, item_counts)
    print()
    print("✅ Set metadata")

    # Close connection
    conn.close()

    # Show database size
    db_size = OUTPUT_DB.stat().st_size
    db_size_mb = db_size / (1024 * 1024)

    print()
    print(f"🎉 Database created successfully!")
    print(f"   Location: {OUTPUT_DB}")
    print(f"   Size: {db_size_mb:.2f} MB")
    print(f"   Total items: {sum(item_counts.values())}")
    print()


if __name__ == '__main__':
    main()
