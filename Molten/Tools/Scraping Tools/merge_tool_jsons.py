#!/usr/bin/env python3
"""
Merge individual manufacturer tool JSON files into a single tools.json

Combines:
- cgbeads_tools.json
- ennion_tools.json
- firebug_tools.json
- leonardo_tools.json
- mikepeterson_tools.json
- taglia_tools.json

Into: tools.json (following the coatings.json pattern)
"""

import json
import sys
from pathlib import Path
from datetime import datetime

def merge_tool_jsons():
    """Merge all tool JSON files into a single tools.json"""

    # Find tool JSON files
    data_dir = Path(__file__).parent.parent.parent / 'Data' / 'Tools'
    tool_files = sorted(data_dir.glob('*_tools.json'))

    if not tool_files:
        print("❌ No tool JSON files found!")
        return 1

    print(f"Found {len(tool_files)} tool JSON files to merge:")
    for f in tool_files:
        print(f"  - {f.name}")

    # Collect all tools
    all_tools = []

    for tool_file in tool_files:
        with open(tool_file, 'r', encoding='utf-8') as f:
            data = json.load(f)

        manufacturer = data.get('manufacturer', 'unknown')
        manufacturer_name = data.get('manufacturer_name', manufacturer)
        manufacturer_url = data.get('manufacturer_url', '')
        tools = data.get('tools', [])

        print(f"\n{manufacturer_name}: {len(tools)} tools")

        # Add manufacturer info to each tool if not present
        for tool in tools:
            if 'manufacturer' not in tool:
                tool['manufacturer'] = manufacturer
            if 'manufacturer_url' not in tool and manufacturer_url:
                tool['manufacturer_url'] = manufacturer_url

            # Ensure all required fields exist
            tool.setdefault('name', '')
            tool.setdefault('sku', '')
            tool.setdefault('category', '')
            tool.setdefault('price', None)
            tool.setdefault('status', 'available')
            tool.setdefault('image_url', '')
            tool.setdefault('description', '')

            all_tools.append(tool)

    # Create merged JSON structure (following coatings.json pattern)
    merged = {
        'version': '1.0',
        'generated': datetime.now().isoformat(),
        'item_count': len(all_tools),
        'tools': all_tools
    }

    # Write merged file
    output_file = data_dir / 'tools.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(merged, f, indent=2, ensure_ascii=False)

    print(f"\n✅ Merged {len(all_tools)} tools into {output_file}")
    print(f"   Version: {merged['version']}")
    print(f"   Generated: {merged['generated']}")

    return 0


if __name__ == '__main__':
    sys.exit(merge_tool_jsons())
