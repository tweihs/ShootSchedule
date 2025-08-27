# ShootSchedule App Design System

## Overview
The ShootSchedule app follows a clean, professional iOS design approach with warm, approachable colors and excellent usability. This style guide documents the visual and interaction patterns to maintain consistency across all Postflight applications.

## Color Palette

### Primary Background
- **Main Background**: `Color(red: 1.0, green: 0.992, blue: 0.973)` 
  - Warm cream/off-white that's easier on the eyes than pure white
  - Used throughout: ContentView, SheetViews, AccountDetailsView

### Accent Colors
- **Primary Blue**: `.blue` (System blue)
  - Used for: Primary actions, links, active states, "Done" buttons
  - Examples: Mark buttons, toolbar buttons, user avatar background
- **Secondary Gray**: `.secondary` 
  - Used for: Supporting text, inactive elements, weather/duration pills
- **System Colors**: 
  - `.primary` for main text
  - `.red` for destructive actions (Remove All Events)
  - `.orange` for maintenance actions (Clean Up Duplicates)

### Component-Specific Colors
- **Cards/Sections**: `Color.white.opacity(0.9)` with `cornerRadius(10)`
- **Search Bar**: `Color.white.opacity(0.8)` for subtle transparency
- **Dividers**: Default system dividers for consistent spacing

## Typography

### Font Hierarchy
- **Headers**: `.system(size: 16, weight: .semibold)` 
- **Body Text**: `.system(size: 15, weight: .medium)` for primary content
- **Secondary Text**: `.system(size: 13, weight: .regular)` for descriptions
- **Small Text**: `.system(size: 11-12, weight: .medium)` for pills/tags
- **Navigation**: `.system(size: 14, weight: .medium)` for controls

### Text Styling Patterns
```swift
// Primary section headers
Text("Section Title")
    .font(.system(size: 16, weight: .semibold))
    .foregroundColor(.primary)

// Body content
Text("Main content")
    .font(.system(size: 15, weight: .medium))
    .foregroundColor(.primary)

// Supporting text
Text("Description or help text")
    .font(.system(size: 13))
    .foregroundColor(.secondary)
```

## Layout & Spacing

### Container Patterns
```swift
VStack(alignment: .leading, spacing: 0) {
    // Section content with consistent spacing
}
.padding()
.background(Color.white.opacity(0.9))
.cornerRadius(10)
```

### Consistent Padding
- **Section containers**: `.padding()` (16pt default)
- **Horizontal margins**: `.padding(.horizontal)` 
- **Vertical sections**: `.padding(.vertical, 8-12)`
- **Between sections**: `Spacer(minLength: 20)` or spacing: 16-20

### Icon Sizing
- **Standard icons**: `.font(.system(size: 16))` with `.frame(width: 24)` for alignment
- **Small icons**: `.font(.system(size: 12-14))` for inline elements
- **Avatar**: `32x32` circular frame

## Component Design Patterns

### Pills/Tags
```swift
Text("Tag Text")
    .font(.system(size: 10-11, weight: .medium))
    .foregroundColor(.secondary)
    .padding(.horizontal, 6-8)
    .padding(.vertical, 2-3)
    .background(
        RoundedRectangle(cornerRadius: 8-10)
            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
    )
```

### Buttons

#### Primary Actions
```swift
Button("Action") { /* action */ }
    .font(.system(size: 15, weight: .medium))
    .foregroundColor(.blue)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color.blue, lineWidth: 1.5)
    )
```

#### Completed/Active State
```swift
HStack {
    Image(systemName: "checkmark")
        .font(.system(size: 14, weight: .bold))
    Text("Completed")
        .font(.system(size: 15, weight: .medium))
}
.foregroundColor(.white)
.frame(maxWidth: .infinity)
.padding(.vertical, 12)
.background(Color.blue)
.cornerRadius(10)
```

### List Rows
```swift
HStack {
    Image(systemName: "icon.name")
        .font(.system(size: 16))
        .foregroundColor(.blue)
        .frame(width: 24)
    
    VStack(alignment: .leading, spacing: 2) {
        Text("Primary Text")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.primary)
        
        Text("Secondary Text")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
    }
    
    Spacer()
    
    Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.secondary)
}
```

### Search & Input
```swift
TextField("Placeholder", text: $text)
    .padding(7)
    .background(Color.white.opacity(0.8))
    .cornerRadius(10)
    .overlay(
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color(UIColor.systemGray4), lineWidth: 1)
    )
```

## Navigation & Structure

### Page Structure
1. **Background**: Always use the warm cream background
2. **Navigation**: `.navigationBarHidden(true)` with custom headers
3. **Content**: Wrapped in `ScrollView` with `VStack(spacing: 0)`
4. **Sections**: Grouped with consistent spacing between them

### Sheet Presentations
- Always apply the background color: `.background(Color(red: 1.0, green: 0.992, blue: 0.973))`
- Use `.navigationBarTitleDisplayMode(.inline)` for consistency

## Interaction Patterns

### Keyboard Handling
- Implement multiple dismissal methods (Done button, scroll, tap outside, swipe down)
- Use `.scrollDismissesKeyboard(.interactively)` for ScrollViews
- Provide clear "Done" toolbar button above keyboard

### State Management
- Use `@StateObject` for data managers
- Use `@State` for local UI state
- Use `@FocusState` for keyboard management
- Debounce heavy operations (300ms for search)

### Loading & Performance
- Run heavy operations on background queues
- Use reactive publishers (Combine) for responsive UI
- Cache expensive calculations
- Provide immediate UI feedback

## Accessibility & Usability

### Touch Targets
- Minimum 44pt touch targets for interactive elements
- Use `.buttonStyle(PlainButtonStyle())` to maintain custom styling
- Provide clear visual feedback for button states

### Content Organization
- Group related functionality in logical sections
- Use consistent section headers
- Provide clear visual hierarchy
- Place diagnostic/advanced features at bottom

### Error Handling
- Use color coding: blue for actions, orange for maintenance, red for destructive
- Provide descriptive helper text
- Use system icons for clear meaning

## Animation & Transitions

### Standard Transitions
```swift
.transition(.move(edge: .trailing))
.animation(.default, value: stateVariable)
```

### State Changes
- Use smooth transitions for state changes
- Avoid jarring animations
- Maintain consistent timing

## Implementation Notes

### SwiftUI Best Practices
- Use `@EnvironmentObject` for shared data managers
- Implement `.onAppear` and `.onDisappear` lifecycle methods
- Use background queues for heavy operations
- Batch multiple tool calls for optimal performance

### Code Organization
- Group related views in folders
- Use consistent naming conventions
- Document complex interactions
- Maintain separation of concerns

## Quality Standards

- **Performance**: Zero UI hitching, responsive interactions
- **Reliability**: Robust error handling, graceful degradation  
- **Consistency**: Apply patterns uniformly across all screens
- **Polish**: Smooth animations, proper spacing, professional appearance

This design system ensures consistency across all Postflight applications while maintaining the professional, approachable aesthetic of ShootSchedule.