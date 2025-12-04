# Changelog

All notable changes to Molten will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

---

## [1.0.2] - 2025-12-04

### Added
- Redeem promo codes directly in the app from the subscription screen

### Fixed
- Minor bug fixes

---

## [1.0.1] - 2025-12-04

### Added
- Allow labels definition updates to be downloaded from server
- Temperature unit setting (Fahrenheit or Celsius) for coating temperature display

### Changed
- Reduced binary download size

### Fixed
- Inventory and shopping list now refresh immediately when iCloud syncs after reinstalling the app
- Improved first-run catalog loading experience

---

## [1.0.0] - TBD

Initial App Store release.

### Added
- Centralized image loading with automatic gradient fallback for items without product photos
- Color chip display mode settings (Always/No Photo/Never)

### Changed
- Image loading now always returns a usable image (product photo, gradient, or manufacturer logo)
- Simplified ProductImageView and HeroHeader components

### Fixed
- Thumbnail fallback when full-size image is unavailable
- Premium "unlimited" banner no longer wastes space on shopping list

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
