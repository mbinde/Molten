#!/usr/bin/env python3
"""
migrate-di.py - Advanced DI Migration Tool

Migrates Swift views from RepositoryFactory to AppDependencies dependency injection.

Usage:
    python3 Scripts/migrate-di.py --analyze <file>          # Analyze file and show plan
    python3 Scripts/migrate-di.py --migrate <file>          # Apply migration
    python3 Scripts/migrate-di.py --batch <directory>       # Migrate all files in directory
"""

import re
import sys
import argparse
from pathlib import Path
from typing import List, Tuple, Set

# Service mapping: RepositoryFactory method -> AppDependencies property
SERVICE_MAP = {
    'createCatalogService': 'catalogService',
    'createInventoryTrackingService': 'inventoryTrackingService',
    'createShoppingListService': 'shoppingListService',
    'createPurchaseRecordService': 'purchaseRecordService',
    'createProjectService': 'projectService',
    'createKilnScheduleService': 'kilnScheduleService',
    'createRecipeService': 'recipeService',
    'createUnifiedLocationService': 'unifiedLocationService',
    'createEntitlementService': 'entitlementService',
    'createGlassItemRepository': 'glassItemRepository',
    'createInventoryRepository': 'inventoryRepository',
    'createLocationRepository': 'locationRepository',
    'createUserImageRepository': 'userImageRepository',
    'createProjectRepository': 'projectRepository',
    'createLogbookRepository': 'logbookRepository',
    'createPurchaseRecordRepository': 'purchaseRecordRepository',
    'createItemTagsRepository': 'itemTagsRepository',
    'createUserTagsRepository': 'userTagsRepository',
    'createShoppingListRepository': 'shoppingListRepository',
}


class DIAnalyzer:
    """Analyzes a Swift file for RepositoryFactory usage patterns"""

    def __init__(self, file_path: Path):
        self.file_path = file_path
        self.content = file_path.read_text()
        self.lines = self.content.splitlines()

    def find_default_parameters(self) -> List[Tuple[int, str, str]]:
        """Find init parameters with RepositoryFactory defaults

        Returns: [(line_num, full_match, factory_method)]
        """
        results = []
        pattern = r'(\w+:\s+\w+)\s*=\s*RepositoryFactory\.(\w+)\(\)'

        for i, line in enumerate(self.lines, 1):
            matches = re.finditer(pattern, line)
            for match in matches:
                results.append((i, match.group(0), match.group(2)))

        return results

    def find_direct_calls(self) -> List[Tuple[int, str, str]]:
        """Find direct RepositoryFactory calls (not in init parameters)

        Returns: [(line_num, full_match, factory_method)]
        """
        results = []
        # Match RepositoryFactory.createX() but not as part of default parameter
        pattern = r'RepositoryFactory\.(\w+)\(\)'

        for i, line in enumerate(self.lines, 1):
            # Skip lines that are default parameters (already handled)
            if '=' in line and 'init(' not in line and ':' in line.split('=')[0]:
                continue

            matches = re.finditer(pattern, line)
            for match in matches:
                results.append((i, match.group(0), match.group(1)))

        return results

    def has_environment_dependencies(self) -> bool:
        """Check if file already has @Environment(\.appDependencies)"""
        return r'@Environment(\.appDependencies)' in self.content

    def needs_environment_dependencies(self) -> bool:
        """Check if file uses 'dependencies.' and needs @Environment"""
        return 'dependencies.' in self.content and not self.has_environment_dependencies()

    def get_used_services(self) -> Set[str]:
        """Get set of AppDependencies properties used in file"""
        services = set()
        for factory_method in SERVICE_MAP:
            if f'RepositoryFactory.{factory_method}' in self.content:
                services.add(SERVICE_MAP[factory_method])
        return services

    def analyze(self) -> dict:
        """Full analysis of file"""
        return {
            'file': str(self.file_path),
            'default_params': self.find_default_parameters(),
            'direct_calls': self.find_direct_calls(),
            'has_env_dependencies': self.has_environment_dependencies(),
            'needs_env_dependencies': self.needs_environment_dependencies(),
            'used_services': self.get_used_services(),
            'total_usages': len(self.find_default_parameters()) + len(self.find_direct_calls()),
        }


class DIMigrator:
    """Applies DI migration transformations to a Swift file"""

    def __init__(self, file_path: Path):
        self.file_path = file_path
        self.content = file_path.read_text()
        self.modified = False

    def remove_default_parameters(self) -> int:
        """Remove RepositoryFactory default values from init parameters

        Returns: number of changes made
        """
        pattern = r'(\w+:\s+\w+)\s*=\s*RepositoryFactory\.\w+\(\)'
        new_content, count = re.subn(pattern, r'\1', self.content)

        if count > 0:
            self.content = new_content
            self.modified = True

        return count

    def replace_direct_calls(self) -> int:
        """Replace RepositoryFactory calls with dependencies.property

        Returns: number of changes made
        """
        count = 0
        for factory_method, property_name in SERVICE_MAP.items():
            pattern = f'RepositoryFactory\\.{factory_method}\\(\\)'
            new_content, n = re.subn(pattern, f'dependencies.{property_name}', self.content)

            if n > 0:
                self.content = new_content
                self.modified = True
                count += n

        return count

    def add_environment_if_needed(self) -> bool:
        """Add @Environment(\.appDependencies) if file uses dependencies

        Returns: True if added
        """
        if 'dependencies.' not in self.content:
            return False

        if r'@Environment(\.appDependencies)' in self.content:
            return False  # Already has it

        # Find the struct/class declaration to add before first property
        struct_match = re.search(r'(struct|class)\s+\w+[^{]*\{', self.content)
        if not struct_match:
            return False

        # Find position after opening brace
        insert_pos = struct_match.end()

        # Add the environment declaration
        env_line = '\n    @Environment(\\.appDependencies) private var dependencies\n'
        self.content = self.content[:insert_pos] + env_line + self.content[insert_pos:]
        self.modified = True

        return True

    def migrate(self) -> dict:
        """Apply all migrations

        Returns: dict with migration statistics
        """
        stats = {
            'default_params_removed': self.remove_default_parameters(),
            'direct_calls_replaced': self.replace_direct_calls(),
            'environment_added': self.add_environment_if_needed(),
            'modified': self.modified,
        }

        return stats

    def save(self, backup: bool = True):
        """Save migrated content back to file"""
        if not self.modified:
            return

        if backup:
            backup_path = self.file_path.with_suffix('.swift.backup')
            backup_path.write_text(self.file_path.read_text())

        self.file_path.write_text(self.content)


def main():
    parser = argparse.ArgumentParser(description='DI Migration Tool for Swift Views')
    parser.add_argument('--analyze', metavar='FILE', help='Analyze file and show migration plan')
    parser.add_argument('--migrate', metavar='FILE', help='Apply migration to file')
    parser.add_argument('--batch', metavar='DIR', help='Migrate all files in directory')

    args = parser.parse_args()

    if args.analyze:
        file_path = Path(args.analyze)
        if not file_path.exists():
            print(f"Error: File not found: {file_path}")
            sys.exit(1)

        analyzer = DIAnalyzer(file_path)
        results = analyzer.analyze()

        print(f"\n{'='*60}")
        print(f"DI Migration Analysis: {results['file']}")
        print(f"{'='*60}\n")

        print(f"📊 Total RepositoryFactory usages: {results['total_usages']}")
        print(f"   - Default parameters: {len(results['default_params'])}")
        print(f"   - Direct calls: {len(results['direct_calls'])}")
        print()

        if results['default_params']:
            print("🔧 Default Parameters to Remove:")
            for line_num, match, method in results['default_params']:
                print(f"   Line {line_num}: {match}")
                print(f"            → Remove default (keep parameter name and type)")
            print()

        if results['direct_calls']:
            print("🔄 Direct Calls to Replace:")
            for line_num, match, method in results['direct_calls']:
                if method in SERVICE_MAP:
                    replacement = f"dependencies.{SERVICE_MAP[method]}"
                    print(f"   Line {line_num}: {match}")
                    print(f"            → {replacement}")
            print()

        if results['used_services']:
            print("📦 Services Used:")
            for service in sorted(results['used_services']):
                print(f"   - dependencies.{service}")
            print()

        if results['needs_env_dependencies']:
            print("⚠️  Needs: @Environment(\\.appDependencies) private var dependencies")
        elif results['has_env_dependencies']:
            print("✅ Already has @Environment(\\.appDependencies)")

        print(f"\n{'='*60}")
        print("To apply migration:")
        print(f"  python3 Scripts/migrate-di.py --migrate {args.analyze}")
        print(f"{'='*60}\n")

    elif args.migrate:
        file_path = Path(args.migrate)
        if not file_path.exists():
            print(f"Error: File not found: {file_path}")
            sys.exit(1)

        print(f"\n{'='*60}")
        print(f"Migrating: {file_path}")
        print(f"{'='*60}\n")

        migrator = DIMigrator(file_path)
        stats = migrator.migrate()

        if stats['modified']:
            migrator.save(backup=True)

            print(f"✅ Migration completed!")
            print(f"   - Default parameters removed: {stats['default_params_removed']}")
            print(f"   - Direct calls replaced: {stats['direct_calls_replaced']}")
            print(f"   - Environment added: {'Yes' if stats['environment_added'] else 'No'}")
            print(f"\n💾 Backup saved: {file_path}.backup")
            print(f"\n📋 Next steps:")
            print(f"   1. Review changes: git diff {file_path}")
            print(f"   2. Update parent views to pass services")
            print(f"   3. Build and test")
        else:
            print(f"✅ No changes needed - file already migrated or doesn't use RepositoryFactory")

    elif args.batch:
        dir_path = Path(args.batch)
        if not dir_path.exists():
            print(f"Error: Directory not found: {dir_path}")
            sys.exit(1)

        files = list(dir_path.rglob('*.swift'))
        print(f"\nScanning {len(files)} Swift files in {dir_path}...")

        migrated = 0
        for file_path in files:
            content = file_path.read_text()
            if 'RepositoryFactory.' in content:
                print(f"\nMigrating: {file_path.relative_to(dir_path)}")
                migrator = DIMigrator(file_path)
                stats = migrator.migrate()

                if stats['modified']:
                    migrator.save(backup=True)
                    migrated += 1
                    print(f"  ✅ Migrated ({stats['direct_calls_replaced']} changes)")

        print(f"\n{'='*60}")
        print(f"Batch migration complete: {migrated} files migrated")
        print(f"{'='*60}\n")

    else:
        parser.print_help()


if __name__ == '__main__':
    main()
