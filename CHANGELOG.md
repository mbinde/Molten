# Changelog

All notable changes to Molten will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Centralized image loading with automatic gradient fallback for items without product photos
- Color chip display mode settings (Always/No Photo/Never)

### Changed
- Image loading now always returns a usable image (product photo, gradient, or manufacturer logo)
- Simplified ProductImageView and HeroHeader components

### Fixed
- Thumbnail fallback when full-size image is unavailable
- Premium "unlimited" banner no longer wastes space on shopping list

---

## [1.0.0] - TBD

Initial App Store release.

### Added
- Glass catalog with 2,500+ items from major manufacturers
- Inventory tracking with multi-location support
- Shopping lists
- CloudKit sync across devices
- Subscription tiers (Free/Premium)

---

<!--
## Release Notes Template

## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes to existing functionality

### Deprecated
- Features that will be removed in future versions

### Removed
- Features that were removed

### Fixed
- Bug fixes

### Security
- Security-related changes
-->
