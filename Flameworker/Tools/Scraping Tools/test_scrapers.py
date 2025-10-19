#!/usr/bin/env python3
"""
Test Suite for Glass Manufacturer Scrapers
===========================================

Tests to verify:
1. All scraper modules can be imported
2. Required functions exist and have correct signatures
3. CSV field consistency across manufacturers
4. Color extractor module works
"""

import sys
import importlib


# Expected CSV fieldnames (from combined_glass_scraper.py)
EXPECTED_FIELDNAMES = [
    'manufacturer',
    'code',
    'name',
    'start_date',
    'end_date',
    'manufacturer_description',
    'tags',
    'synonyms',
    'coe',
    'type',
    'manufacturer_url',
    'image_path',
    'image_url',
    'stock_type'
]

# Manufacturer modules to test
MANUFACTURER_MODULES = ['boro_batch', 'cim', 'double_helix', 'glass_alchemy', 'tag']


def test_module_imports():
    """Test that all scraper modules can be imported"""
    print("Testing module imports...")

    failures = []
    for module_name in MANUFACTURER_MODULES:
        try:
            module = importlib.import_module(f'scrapers.{module_name}')
            print(f"  ✅ {module_name}: Imported successfully")
        except Exception as e:
            print(f"  ❌ {module_name}: Import failed - {e}")
            failures.append((module_name, str(e)))

    if failures:
        print(f"\n❌ {len(failures)} module(s) failed to import")
        return False
    else:
        print(f"\n✅ All {len(MANUFACTURER_MODULES)} modules imported successfully")
        return True


def test_required_functions():
    """Test that each module has required functions with correct signatures"""
    print("\nTesting required functions...")

    failures = []
    for module_name in MANUFACTURER_MODULES:
        try:
            module = importlib.import_module(f'scrapers.{module_name}')

            # Check for scrape() function
            if not hasattr(module, 'scrape'):
                failures.append((module_name, 'Missing scrape() function'))
                print(f"  ❌ {module_name}: Missing scrape() function")
                continue

            # Check for format_products_for_csv() function
            if not hasattr(module, 'format_products_for_csv'):
                failures.append((module_name, 'Missing format_products_for_csv() function'))
                print(f"  ❌ {module_name}: Missing format_products_for_csv() function")
                continue

            # Check function signatures (basic check - they should be callable)
            if not callable(module.scrape):
                failures.append((module_name, 'scrape() is not callable'))
                print(f"  ❌ {module_name}: scrape() is not callable")
                continue

            if not callable(module.format_products_for_csv):
                failures.append((module_name, 'format_products_for_csv() is not callable'))
                print(f"  ❌ {module_name}: format_products_for_csv() is not callable")
                continue

            # Check for module constants
            required_constants = ['MANUFACTURER_CODE', 'MANUFACTURER_NAME', 'COE']
            missing_constants = [c for c in required_constants if not hasattr(module, c)]

            if missing_constants:
                failures.append((module_name, f'Missing constants: {", ".join(missing_constants)}'))
                print(f"  ⚠️  {module_name}: Missing constants: {', '.join(missing_constants)}")
            else:
                print(f"  ✅ {module_name}: All required functions and constants present")

        except Exception as e:
            failures.append((module_name, str(e)))
            print(f"  ❌ {module_name}: Error - {e}")

    if failures:
        print(f"\n❌ {len(failures)} module(s) failed function checks")
        return False
    else:
        print(f"\n✅ All modules have required functions")
        return True


def test_color_extractor():
    """Test that color_extractor module works"""
    print("\nTesting color_extractor...")

    try:
        from color_extractor import extract_tags_from_name

        # Test some color extractions
        test_cases = [
            ("Sky Blue", '"blue"'),
            ("Red and Green", '"green", "red"'),  # Sorted alphabetically
            ("Clear", '"clear"'),
            ("Something Random", '"unknown"'),
        ]

        all_passed = True
        for test_input, expected in test_cases:
            result = extract_tags_from_name(test_input)
            if result == expected:
                print(f"  ✅ '{test_input}' -> {result}")
            else:
                print(f"  ❌ '{test_input}' -> {result} (expected {expected})")
                all_passed = False

        if all_passed:
            print("\n✅ Color extractor working correctly")
            return True
        else:
            print("\n❌ Some color extraction tests failed")
            return False

    except Exception as e:
        print(f"  ❌ Error testing color_extractor: {e}")
        return False


def test_csv_field_consistency():
    """Test that format_products_for_csv() returns correct fields"""
    print("\nTesting CSV field consistency...")

    failures = []
    for module_name in MANUFACTURER_MODULES:
        try:
            module = importlib.import_module(f'scrapers.{module_name}')

            # Create a minimal test product
            test_product = {
                'name': 'Test Product',
                'sku': 'TEST-001',
                'manufacturer_description': 'Test description',
                'image_url': 'https://example.com/image.jpg',
                'manufacturer_url': 'https://example.com/product',
                'url': 'https://example.com/product',
                'product_type': 'rod'
            }

            # Double Helix needs summary_text and stock_type
            if module_name == 'double_helix':
                test_product['summary_text'] = 'Blue color'
                test_product['stock_type'] = 'available'

            # Format for CSV
            csv_rows = module.format_products_for_csv([test_product])

            if not csv_rows:
                failures.append((module_name, 'format_products_for_csv() returned empty list'))
                print(f"  ❌ {module_name}: Returned empty list")
                continue

            # Check first row has all expected fields
            row = csv_rows[0]
            missing_fields = [field for field in EXPECTED_FIELDNAMES if field not in row]
            extra_fields = [field for field in row if field not in EXPECTED_FIELDNAMES]

            if missing_fields:
                failures.append((module_name, f'Missing fields: {", ".join(missing_fields)}'))
                print(f"  ❌ {module_name}: Missing fields: {', '.join(missing_fields)}")
            elif extra_fields:
                failures.append((module_name, f'Extra fields: {", ".join(extra_fields)}'))
                print(f"  WARNING {module_name}: Extra fields: {', '.join(extra_fields)}")
            else:
                print(f"  ✅ {module_name}: All CSV fields present and correct")

        except Exception as e:
            failures.append((module_name, str(e)))
            print(f"  ❌ {module_name}: Error - {e}")
            import traceback
            traceback.print_exc()

    if failures:
        print(f"\n❌ {len(failures)} module(s) failed CSV field checks")
        return False
    else:
        print(f"\n✅ All modules return consistent CSV fields")
        return True


def test_combined_scraper():
    """Test that combined_glass_scraper.py can be imported"""
    print("\nTesting combined_glass_scraper...")

    try:
        import combined_glass_scraper

        # Check that MANUFACTURERS dict exists
        if not hasattr(combined_glass_scraper, 'MANUFACTURERS'):
            print("  ❌ Missing MANUFACTURERS dict")
            return False

        # Check that all our modules are registered
        manufacturers = combined_glass_scraper.MANUFACTURERS
        registered_codes = list(manufacturers.keys())

        expected_codes = ['BB', 'CIM', 'DH', 'GA', 'TAG']
        missing_codes = [code for code in expected_codes if code not in registered_codes]

        if missing_codes:
            print(f"  ❌ Missing manufacturer codes: {', '.join(missing_codes)}")
            return False

        print(f"  ✅ All {len(expected_codes)} manufacturers registered")
        print(f"  ✅ combined_glass_scraper imports successfully")
        return True

    except Exception as e:
        print(f"  ❌ Error importing combined_glass_scraper: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_database_updater():
    """Test that update_database.py can be imported and has required components"""
    print("\nTesting update_database.py...")

    try:
        import update_database

        # Check for ProductDatabase class
        if not hasattr(update_database, 'ProductDatabase'):
            print("  ❌ Missing ProductDatabase class")
            return False

        # Check for git_commit_changes function
        if not hasattr(update_database, 'git_commit_changes'):
            print("  ❌ Missing git_commit_changes function")
            return False

        # Check database schema version constant
        if not hasattr(update_database, 'DATABASE_VERSION'):
            print("  ❌ Missing DATABASE_VERSION constant")
            return False

        # Try to instantiate ProductDatabase (should create empty database)
        import tempfile
        import os

        # Create a temp path that doesn't exist yet (so db creates new)
        test_db_path = tempfile.mktemp(suffix='.json')

        try:
            db = update_database.ProductDatabase(test_db_path)

            # Check database structure
            if 'version' not in db.data:
                print("  ❌ Database missing 'version' field")
                return False

            if 'products' not in db.data:
                print("  ❌ Database missing 'products' field")
                return False

            # Test duplicate detection with sample data
            sample_data = [
                {'manufacturer': 'BB', 'code': 'TEST-001', 'name': 'Test Product 1'},
                {'manufacturer': 'BB', 'code': 'TEST-001', 'name': 'Test Product 1 Duplicate'}  # Duplicate!
            ]

            has_duplicates, report = db.detect_duplicates(sample_data)

            if not has_duplicates:
                print("  ❌ Duplicate detection failed to detect duplicate")
                return False

            print("  ✅ ProductDatabase class works correctly")
            print("  ✅ Duplicate detection works")
            print("  ✅ Database schema is valid")

            return True

        finally:
            # Cleanup test file
            if os.path.exists(test_db_path):
                os.remove(test_db_path)

    except Exception as e:
        print(f"  ❌ Error testing update_database: {e}")
        import traceback
        traceback.print_exc()
        return False


def main():
    """Run all tests"""
    print("=" * 70)
    print("GLASS SCRAPER TEST SUITE")
    print("=" * 70)
    print()

    results = []

    # Run tests
    results.append(("Module Imports", test_module_imports()))
    results.append(("Required Functions", test_required_functions()))
    results.append(("Color Extractor", test_color_extractor()))
    results.append(("CSV Field Consistency", test_csv_field_consistency()))
    results.append(("Combined Scraper", test_combined_scraper()))
    results.append(("Database Updater", test_database_updater()))

    # Print summary
    print("\n" + "=" * 70)
    print("TEST SUMMARY")
    print("=" * 70)

    passed = sum(1 for _, result in results if result)
    total = len(results)

    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status}: {test_name}")

    print()
    print(f"Tests passed: {passed}/{total}")

    if passed == total:
        print("\n🎉 All tests passed!")
        return 0
    else:
        print(f"\n❌ {total - passed} test(s) failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())
