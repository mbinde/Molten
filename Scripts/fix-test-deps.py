#!/usr/bin/env python3
"""
fix-test-deps.py - Fix test files that use deps.* but don't define deps variable

Finds test functions that use 'deps.' but don't have 'let deps = AppDependencies(...)'
and adds it at the start of each function.
"""

import re
import sys
from pathlib import Path

def fix_test_file(file_path: Path) -> bool:
    """Fix a single test file by adding missing deps declarations

    Returns: True if file was modified
    """
    content = file_path.read_text()
    lines = content.splitlines()

    modified = False
    new_lines = []

    # Track if we're inside a test function
    in_test_function = False
    function_start_line = -1
    function_uses_deps = False
    function_has_deps = False
    function_indent = ""

    for i, line in enumerate(lines):
        # Detect test function start
        if re.match(r'\s*@Test\(|  @Test\s+func ', line) or re.match(r'\s*func test\w+', line):
            # Save previous function state
            if in_test_function and function_uses_deps and not function_has_deps:
                # Need to add deps declaration
                print(f"  Adding deps to function starting at line {function_start_line + 1}")
                # Insert deps line after function opening brace
                for j in range(function_start_line, len(new_lines)):
                    if '{' in new_lines[j]:
                        # Find the brace and insert after it
                        indent = function_indent + "    "
                        deps_line = f"{indent}let deps = AppDependencies(forTesting: true)"
                        new_lines.insert(j + 1, deps_line)
                        modified = True
                        break

            in_test_function = True
            function_start_line = len(new_lines)
            function_uses_deps = False
            function_has_deps = False

            # Detect indent level
            function_indent = re.match(r'^(\s*)', line).group(1)

        # Detect end of function
        if in_test_function and line.strip() == '}' and not line.strip().startswith('//'):
            # Check if this is the closing brace at the same indent level
            current_indent = re.match(r'^(\s*)', line).group(1)
            if len(current_indent) <= len(function_indent):
                # Function ended - check if we need to add deps
                if function_uses_deps and not function_has_deps:
                    print(f"  Adding deps to function starting at line {function_start_line + 1}")
                    # Insert deps line after function opening brace
                    for j in range(function_start_line, len(new_lines)):
                        if '{' in new_lines[j]:
                            indent = function_indent + "    "
                            deps_line = f"{indent}let deps = AppDependencies(forTesting: true)"
                            new_lines.insert(j + 1, deps_line)
                            modified = True
                            break

                in_test_function = False

        # Check if this line uses deps
        if in_test_function and re.search(r'\bdeps\.', line):
            function_uses_deps = True

        # Check if this line defines deps
        if in_test_function and re.search(r'let deps\s*=\s*AppDependencies', line):
            function_has_deps = True

        new_lines.append(line)

    if modified:
        file_path.write_text('\n'.join(new_lines) + '\n')
        return True

    return False


def main():
    # Find all test files
    test_dir = Path("Molten/Tests")

    if not test_dir.exists():
        print(f"Error: {test_dir} not found")
        sys.exit(1)

    files = list(test_dir.rglob("*.swift"))

    print(f"Scanning {len(files)} test files...")
    print()

    fixed_count = 0

    for file_path in files:
        # Check if file uses deps but might be missing declarations
        content = file_path.read_text()

        if 'deps.' in content:
            # Check if any test functions are missing deps declaration
            # This is a heuristic - we'll try to fix and see if it helps
            print(f"Checking: {file_path.relative_to(test_dir.parent)}")

            try:
                if fix_test_file(file_path):
                    fixed_count += 1
                    print(f"  ✅ Fixed")
                else:
                    print(f"  ℹ️  No changes needed")
            except Exception as e:
                print(f"  ❌ Error: {e}")

            print()

    print(f"{'='*60}")
    print(f"Fixed {fixed_count} test files")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
