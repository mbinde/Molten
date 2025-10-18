# Tests to Add for Tags Feature

The following test files should be added to the FlameworkerTests target through Xcode (File > Add Files to "Flameworker" and make sure to check the FlameworkerTests target):

## 1. GlassItemCardTagsTests.swift

Tests for GlassItemCard tags functionality (16 test cases):

- `testGlassItemCardAcceptsSystemTags` - Card accepts system tags parameter
- `testGlassItemCardAcceptsUserTags` - Card accepts user tags parameter
- `testGlassItemCardAcceptsBothTagTypes` - Card accepts both system and user tags
- `testGlassItemCardAcceptsManageCallback` - Card accepts onManageTags callback
- `testGlassItemCardHandlesEmptyTags` - Card handles empty tag arrays
- `testGlassItemCardHandlesManyTags` - Card handles large number of tags (15 total)
- `testGlassItemCardHandlesDuplicateTags` - Card handles duplicate tags across system/user
- `testGlassItemCardCompactVariantWithTags` - Compact variant works with tags
- `testGlassItemCardHandlesSpecialCharacterTags` - Tags with dashes, underscores, dots
- `testGlassItemCardHandlesLongTagNames` - Very long tag names
- `testGlassItemCardVariantConsistency` - Both variants work with same tags
- `testGlassItemCardHandlesNilCallback` - Card works without onManageTags callback
- `testGlassItemCardHandlesMixedCaseTags` - Mixed case tag names
- `testGlassItemCardHandlesEmojiTags` - Emoji characters in tags
- `testGlassItemCardOnlyUserTags` - Only user tags, no system tags
- `testGlassItemCardOnlySystemTags` - Only system tags, no user tags

## 2. InventoryDetailViewTagsIntegrationTests.swift

Tests for InventoryDetailView tags integration (10 test cases):

- `testInventoryDetailViewPassesSystemTags` - View passes system tags to card
- `testInventoryDetailViewLoadsUserTags` - View loads user tags from repository
- `testInventoryDetailViewPassesBothTagTypes` - View passes both tag types to card
- `testInventoryDetailViewProvidesManageCallback` - View provides onManageTags callback
- `testInventoryDetailViewReloadsTagsAfterEditing` - View reloads tags after sheet dismisses
- `testInventoryDetailViewHandlesNoTags` - View handles items with no tags
- `testInventoryDetailViewHandlesManyTags` - View handles 20+ tags efficiently
- `testInventoryDetailViewShowsTagsEditor` - View shows UserTagsEditor sheet
- `testInventoryDetailViewHandlesTagLoadingErrors` - View handles repository errors gracefully
- `testInventoryDetailViewMaintainsTagState` - View maintains tag state across updates

## Implementation Notes

Both test files are located in the repository at:
- `/Users/binde/Library/Mobile Documents/com~apple~CloudDocs/Flameworker/Flameworker/Tests/FlameworkerTests/`

They were removed from the filesystem to fix a build error (they were being compiled with the main app target instead of the test target).

To add them:
1. Restore the files from git history or recreate them
2. Add them to Xcode using File > Add Files to "Flameworker"
3. Ensure the "Target Membership" checkbox is checked ONLY for FlameworkerTests
4. Do NOT check the Flameworker (main app) target

## Coverage

These tests provide comprehensive coverage for:
- GlassItemCard accepting and displaying tags
- Visual distinction between system and user tags
- Collapsible tags functionality
- Tag management callback integration
- InventoryDetailView integration with tags
- Error handling and edge cases
- Performance with many tags
- Various tag content types (special chars, emoji, long names, etc.)
