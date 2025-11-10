#!/bin/bash

# Set build number to git commit count
# This script is run as a build phase in Xcode to automatically
# set CFBundleVersion to the current git commit count.

if [ -d ".git" ]; then
    BUILD_NUMBER=$(git rev-list --count HEAD)

    # Update the Info.plist in the built app
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

    echo "✅ Build number set to: $BUILD_NUMBER (commit count)"
else
    echo "⚠️  Not a git repository, skipping build number update"
fi
