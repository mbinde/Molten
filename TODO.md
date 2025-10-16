# Flameworker TODO List

## UI Components

### Create Reusable Components Library

Build a library of reusable UI components in `Views/Shared/Components/` to ensure consistency across the app.

**Components to create:**

1. **CardView.swift** - Standard card container
   - Replaces repeated card styling patterns
   - Uses `DesignSystem` for padding, background, and corner radius
   - Optional header, footer, and shadow support

2. **SectionHeader.swift** - Consistent section headers
   - Used across all list sections
   - Standard font (title2 + semibold) and spacing
   - Optional action button support

3. **EmptyStateView.swift** - Standard empty states
   - Icon, title, description, optional button
   - Consistent spacing and typography
   - Configurable icon and colors

4. **LoadingView.swift** - Standard loading indicators
   - Spinner with optional message
   - Consistent styling and positioning
   - Support for inline vs. full-screen loading

5. **ErrorView.swift** - Standard error displays
   - Error icon, message, optional retry button
   - Consistent error styling
   - Support for different error types

6. **TagView.swift** - Reusable tag/chip component
   - Selected vs. unselected states
   - Consistent padding and corner radius
   - Color variants (blue, green, gray, etc.)

7. **SearchBarView.swift** - Standard search bar
   - Magnifying glass icon, text field, clear button
   - Consistent background and styling
   - Optional filter button

8. **FormSection.swift** - Reusable form section container
   - Label, input field, helper text, error message
   - Consistent spacing and typography
   - Support for various input types

**Benefits:**
- Reduce code duplication across views
- Ensure UI consistency automatically
- Easier to update design system-wide
- Better developer experience

**Acceptance Criteria:**
- All components use `DesignSystem` constants
- Components are documented with usage examples
- Existing views can optionally migrate to use these components
- Components support both light and dark mode
