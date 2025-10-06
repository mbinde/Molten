#!/bin/bash
# Simple test runner to check if our tests pass
cd /repo
xcodebuild test -scheme Flameworker -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FlameworkerTests/ManufacturerFilterTests 2>&1 | grep -E "(PASS|FAIL|Test Suite)"