# Design Refresh Project - Working Agreement

Reference document for maintaining alignment across sessions.

---

## Core Objectives

### 1. Design System Foundation
- Create reusable, centralized UI components (buttons, cards, text styles, colors, spacing)
- Single source of truth: change once, update everywhere
- Focus on maintainability and visual consistency

### 2. Accessibility Preservation
- Maintain/add accessibility identifiers for VoiceOver and UI tests
- Follow existing pattern: `feature.element[.specifics]`
- Never break existing test infrastructure

### 3. Mockups = Style Guides, Not Feature Specs
- Apply visual language (typography, spacing, color, layout) from mockups
- Existing functionality stays intact—we're reskinning, not removing features
- If mockup shows 3 styled fields, apply that style to all 10 existing fields

---

## Critical Constraint: iOS First

**The mockups were created by Gemini (Google), which may have Android design bias.**

We follow iOS/Apple Human Interface Guidelines:
- Native iOS navigation patterns (tab bars, navigation stacks, sheets)
- SF Symbols for icons
- System fonts (SF Pro) unless brand requires otherwise
- iOS-standard controls (toggles, pickers, segmented controls)
- Platform-appropriate gestures and interactions
- Respect Safe Areas and Dynamic Type

When mockups conflict with iOS conventions, **iOS conventions win**.

---

## What We're NOT Doing
- Removing existing features/fields not shown in mockups
- Blindly copying Android-style patterns
- Breaking accessibility or UI tests
- One-off styling (everything goes through the design system)

---

## Session Workflow

1. Review mockup(s) for target screen
2. Identify iOS-appropriate interpretation
3. Create/update design system components as needed
4. Apply to existing views, preserving all functionality
5. Verify accessibility identifiers are in place
6. Test that UI tests still pass

---

## Files to Track

| File | Purpose |
|------|---------|
| `Sources/Utilities/DesignSystem.swift` | Colors, typography, spacing, corner radius |
| `Sources/Views/Shared/Components/InventoryCountBadge.swift` | SF Rounded inventory counts |
| `Sources/Views/Shared/Components/GlassItemRowView.swift` | Unified list row for all screens |
| `Sources/Views/Shared/Components/ColorSwatchView.swift` | Glass color swatch with size presets |
| `design-notes/` | Mockups, decisions, this document |

---

## Progress Log

### 2025-11-24: Foundation Components

**Completed:**
1. **DesignSystem.swift** - Updated with "Luminous Precision" palette
   - Brand colors: `moltenOrange`, `moltenAmber`, `moltenTeal`, `moltenAsh`
   - Semantic typography: `listItemTitle`, `listItemSubtitle`, `prominentNumber`, etc.
   - `Color.molten*` extensions for grep-able usage
   - Deprecated aliases for migration

2. **InventoryCountBadge** - New component
   - SF Rounded font for prominent numbers
   - Color-coded: teal (in-stock), amber (low stock), gray (out)
   - Three styles: `.large`, `.compact`, `.minimal`

3. **GlassItemRowView** - Updated to design system
   - All hardcoded colors → `DesignSystem.Colors.*`
   - All hardcoded fonts → `DesignSystem.Typography.*`
   - All hardcoded spacing → `DesignSystem.Spacing.*`

4. **ColorSwatchView** - Added size presets
   - `.small` (40pt), `.medium` (60pt), `.large` (80pt), `.hero` (120pt)

5. **CLAUDE.md** - Added Design System section with rules and grep command

**Violation Detection:**
```bash
grep -r "Color\.\(red\|blue\|green\|orange\|yellow\|purple\|pink\|cyan\)" Molten/Sources/Views/
```

---

*Last updated: 2025-11-24*
