# Camera UI Design Prototypes

## Overview

Three distinct camera interface prototypes have been created to address design issues in the current `MultiPhotoCameraView`. Each prototype takes a fundamentally different approach to organizing controls, managing visual hierarchy, and optimizing user interaction.

All prototypes:
- Maintain complete functionality (all original controls present)
- Support both Single-Item and Multi-Item capture modes
- Use static asset images (`blender.imageset`) instead of live camera feed
- Are accessible from the Dashboard via dedicated launch buttons
- Include proper state management and environment object injection

**Location**: `/Users/camden.webster/dev/MovingBox/MovingBox/Views/Camera/CameraPrototypes.swift`

---

## Prototype 1: Zone-Based Control Layout

**File**: `ZoneBasedCameraPrototypeView`
**Icon**: Square grid (🟦 blue accent)
**Philosophy**: Professional zone-based architecture with clear functional separation

### Layout Structure

The interface is organized into five distinct horizontal zones:

```
┌─────────────────────────┐
│ TOP BAR: Settings       │ ← Flash mode, close, done
├─────────────────────────┤
│ CAMERA PREVIEW          │
│ [Square guide]          │
│ [Zoom controls]         │ ← Floating center overlay
├─────────────────────────┤
│ MODE BAR                │ ← Segmented control
├─────────────────────────┤
│ THUMBNAILS (single)     │ ← Horizontal scroll
├─────────────────────────┤
│ CAPTURE ZONE            │ ← Shutter, counter, picker
└─────────────────────────┘
```

### Key Features

**Top Settings Bar** (60pt height)
- Close button: Left
- Flash toggle: Center-left with text label and icon
- Done button: Right, green text
- Minimal, always visible

**Zoom Controls** (Floating overlay)
- Positioned 80pt above mode bar
- 4 buttons: 0.5x, 1x, 2x, 5x
- Yellow highlight for active zoom
- Semi-transparent black background

**Mode Selection Bar** (Dedicated zone, 60pt)
- Full-width segmented control
- Clear visual emphasis with background tint
- Large touch targets
- Positioned between preview and thumbnails

**Thumbnail Zone** (90pt height, single-item mode)
- Horizontal scroll, edge-to-edge
- 70×70pt thumbnails with delete buttons
- Semi-transparent background overlay
- Shows capture progress visually

**Capture Zone** (120pt height)
- Photo counter: Left side (70pt width)
- Shutter button: Center, 76pt diameter, green
- Photo picker: Right side (44×44pt)
- Retake button: Right side when photos exist

### Mode-Specific Behaviors

**Single-Item Mode**:
- Green accent color throughout
- Thumbnails visible
- Photo counter shows "X of 5" (pro) or "1 of 1" (free)
- Done button always accessible

**Multi-Item Mode**:
- Blue accent color
- No thumbnails (after capture: full-screen preview overlay)
- Photo counter hidden
- Retake + Analyze buttons overlay preview

### Advantages

✓ **Clear Visual Hierarchy**: Distinct zones prevent cognitive overload
✓ **Predictable Muscle Memory**: Fixed-height zones aid muscle memory
✓ **Thumb-Friendly**: All critical controls in reachable bottom area
✓ **Professional Appearance**: Resembles pro camera apps
✓ **All Controls Visible**: No hidden or hard-to-find features

### Trade-offs

✗ Takes up more vertical space
✗ Less preview area (60% vs 80%)
✗ Requires scrolling on small devices

---

## Prototype 2: Floating Action Button (FAB) System

**File**: `FABSystemCameraPrototypeView`
**Icon**: Circle with bottom split (🟣 purple accent)
**Philosophy**: Minimal interface with context-sensitive floating controls

### Layout Structure

```
┌─────────────────────────┐
│ MINIMAL HEADER          │ ← Just close and done
├─────────────────────────┤
│ CAMERA PREVIEW          │
│ [Square guide]          │
│                    [S]  │ ← Right-edge FAB stack
│ 0.5 1 2 5             M │
│                    [⚙️] │
│            [SHUTTER] 🟢  │ ← Large right-edge shutter
│                         │
│ [▣▣▣] 1/5              │ ← Collapsed thumbnails (left)
└─────────────────────────┘
```

### Key Features

**Minimal Header** (44pt)
- Only close and done buttons
- Translucent background
- Maximum preview visibility

**Right-Edge FAB Stack** (Vertical, 44pt each)
- Position: Right edge, 120pt from top
- Settings FAB (gear icon) - expands to reveal options
- Mode selector (compact: S | M)
- Spacing: 8pt between buttons

**Zoom Controls** (Floating strip)
- Position: Right-aligned below FAB stack
- 4 horizontal buttons
- Auto-hides after 2 seconds of inactivity
- Appears on: capture, zoom change, manual tap

**Shutter FAB** (82pt diameter)
- Position: Right edge, 30pt from bottom
- Color-coded: Green (single), Blue (multi)
- Pulsing animation when ready
- Large touch target for reliable tapping

**Thumbnail Strip** (Collapsed, 60pt height)
- Position: Bottom-left corner
- Shows only 3 thumbnails + count badge
- Tap to expand full scroll view
- Single-item mode only

**Photo Picker FAB** (50pt diameter)
- Position: Bottom-left, above thumbnails
- Only visible when not at max photos
- Material background with icon

### Mode-Specific Behaviors

**Single-Item Mode**:
- Green shutter FAB
- Thumbnail strip visible bottom-left
- Multiple captures allowed
- Counter badge on thumbnails

**Multi-Item Mode**:
- Blue shutter FAB
- No thumbnails
- After capture: Full-screen preview with centered buttons
- One-shot capture only

### Advantages

✓ **Maximum Preview Space**: 80% of screen for camera feed
✓ **Modern Aesthetic**: Aligns with contemporary app patterns
✓ **Context-Sensitive**: Controls appear/hide based on state
✓ **One-Handed Friendly**: All controls on right edge
✓ **Gesture-Rich**: Swipe and tap interactions
✓ **Clean & Minimal**: Uncluttered interface

### Trade-offs

✗ Steeper learning curve for first-time users
✗ Controls hidden by default (discoverability issue)
✗ Right-handed bias (harder for left-handed users)
✗ Small targets may be hard for users with accessibility needs

---

## Prototype 3: Two-Stage Interface

**File**: `TwoStageCameraPrototypeView`
**Icon**: Checklist (📋 orange accent)
**Philosophy**: Separate setup configuration from capture operation

### Layout Structure

**STAGE 1: Setup Screen**
```
┌─────────────────────────┐
│ [X] Camera Setup [▶]   │ ← Header with navigation
├─────────────────────────┤
│                         │
│  Choose Capture Mode    │ ← Section title
│                         │
│  ┌──────────┬──────────┐│
│  │  SINGLE  │  MULTI   ││ ← Large mode cards
│  │ 📸       │ 📸📸     ││
│  │ Multiple │ Multiple ││
│  └──────────┴──────────┘│
│                         │
│  Camera Settings        │ ← Settings panel
│  Flash: [A][On][Off]    │
│  Zoom:  [0.5][1][2][5]  │
│  Camera: [Front][Back]  │
└─────────────────────────┘
```

**STAGE 2: Capture Screen** (After mode selection)
```
┌─────────────────────────┐
│ [←] Single Mode [✓]    │ ← Can go back to setup
├─────────────────────────┤
│ CAMERA PREVIEW          │
│ [Square guide]          │
│                         │
│ THUMBNAILS (if single)  │ ← Only in single mode
│  [▣] [▣] [▣]           │
│                         │
│   1 of 5    (O)         │ ← Clean capture UI
└─────────────────────────┘
```

### Key Features

**STAGE 1 - Setup Screen**

*Navigation Header* (50pt)
- Close button: Left
- Title: "Camera Setup"
- Continue arrow: Right (disabled until mode selected)

*Mode Selection Cards* (160pt height each, 2 columns)
- Centered vertically
- Full visual explanation with icons
- Active card highlighted with border
- Tap entire card to select mode
- Shows pro badge if mode requires subscription

*Settings Panel* (Bottom 200pt)
- Flash: 3 segmented options (Auto, On, Off)
- Zoom: 4 buttons (0.5x, 1x, 2x, 5x)
- Camera: Front/Back toggle
- Professional grouped layout

**STAGE 2 - Capture Screen**

*Navigation Header* (50pt)
- Back arrow: Returns to setup
- Mode indicator: Current mode (non-editable)
- Done checkmark: Right side

*Camera Preview* (Full height minus controls)
- Clean, uncluttered
- Square guide overlay
- Tap-to-focus only
- Hidden controls

*Thumbnails* (Single mode: 80pt height)
- Horizontal scroll
- Compact layout
- Shows progress visually
- Only in single-item mode

*Quick Settings* (Hidden by default)
- Swipe down from top to reveal
- Change flash, zoom, camera without leaving stage
- Panel slides over preview with blur
- Swipe up to hide

*Shutter Area* (80pt height, bottom)
- Photo counter: Left third
- Shutter: Center, 70pt diameter
- Photo picker: Right third (single mode)

### Mode-Specific Behaviors

**Single-Item Mode**:
- Stage 1: Green card highlight
- Stage 2: Green accents, thumbnails visible
- Can return to stage 1 to reconfigure
- Progressive photo addition
- Supports multiple captures

**Multi-Item Mode**:
- Stage 1: Blue card highlight
- Stage 2: Blue accents, no thumbnails
- After capture: Immediate transition to preview
- [Retake] returns to Stage 2, [Analyze] proceeds
- One-shot capture only

### Advantages

✓ **Clear Mental Model**: Two stages = two purposes
✓ **User Education**: Mode differences explained before shooting
✓ **Uncluttered Capture**: Stage 2 is purely for taking photos
✓ **Easy Reconfiguration**: Back button returns to setup
✓ **Accessibility**: Large touch targets, clear hierarchy
✓ **First-Time Success**: Educated mode choice reduces errors

### Trade-offs

✗ Requires extra step (mode selection) each session
✗ Can't quickly switch modes without restarting
✗ More screens to navigate
✗ Settings hidden unless manually revealed

---

## Implementation Details

### Files Created

**Primary**:
- `/MovingBox/Views/Camera/CameraPrototypes.swift` - All 3 prototypes

**Modified**:
- `/MovingBox/Views/Home\ Views/DashboardView.swift` - Added prototype launch buttons

### Static Image Usage

All prototypes use `"blender"` from TestAssets.xcassets:
- Scaled to fit 3:4 aspect ratio (portrait)
- Replaces live camera feed
- Allows easy visual testing of UI layouts

### Accessing the Prototypes

From the Dashboard:

1. Scroll down past "Recently Added" and "Location Statistics"
2. Find "Camera Prototypes" section
3. Three buttons: "Zone-Based" (blue), "FAB System" (purple), "Two-Stage" (orange)
4. Tap any button to open that prototype in a sheet
5. All controls are interactive (photo counter increments, modes toggle, etc.)

### Component Integration

All prototypes:
- Use `@EnvironmentObject var settings: SettingsManager` for pro features
- Support Single-Item and Multi-Item modes
- Track photo count and manage captured images
- Implement zoom selection (though not connected to actual camera)
- Use proper spacing and color theming

---

## Comparison Matrix

| Aspect | Zone-Based | FAB System | Two-Stage |
|--------|-----------|-----------|-----------|
| **Preview Space** | 60% | 80% | 70% (Stage 2) |
| **All Controls Visible** | Yes | No | Yes (Stage 1) |
| **Learning Curve** | Low | Medium | Very Low |
| **One-Handed Use** | Good (bottom focus) | Excellent (right edge) | Good (large targets) |
| **Visual Hierarchy** | Very Clear | Context-dependent | Extremely Clear |
| **Reconfiguration** | Mid-screen toggle | FAB stack | Back button |
| **Best For** | Power users, frequent switchers | Experienced users | First-time users |
| **Gesture Complexity** | Simple taps | Taps + swipes | Simple navigation |
| **Professional Feel** | ★★★★★ | ★★★★☆ | ★★★☆☆ |
| **Modern Aesthetic** | ★★★★☆ | ★★★★★ | ★★★★☆ |

---

## Design Recommendations

### Choose Zone-Based if:
- Users need quick access to all controls
- Professional camera app feel is desired
- Mode switching happens frequently mid-session
- Users are experienced with camera apps
- Maximum clarity is a priority

### Choose FAB System if:
- Preview quality is paramount
- App has modern gesture-driven UX elsewhere
- Target users are tech-savvy
- Right-to-left gesture support isn't critical
- Floating UI patterns are used elsewhere in app

### Choose Two-Stage if:
- User education is important
- Mode confusion is a current pain point
- First-time success rate needs improvement
- Simplicity and clarity trump feature discovery
- Target users include less tech-savvy audience

---

## Next Steps

1. **User Testing**: Conduct usability tests with representative users on each prototype
2. **Analytics**: Track which prototype (if any) resonates best
3. **Refinement**: Based on feedback, refine the selected prototype
4. **Integration**: Replace current camera view with refined design
5. **A/B Testing**: Deploy as feature flag to measure real-world usage patterns

---

## Files & Structure

```
MovingBox/
├── Views/
│   ├── Camera/
│   │   ├── MultiPhotoCameraView.swift      (current)
│   │   └── CameraPrototypes.swift          (new - all 3 prototypes)
│   └── Home\ Views/
│       └── DashboardView.swift             (modified - added prototype buttons)
```

**Prototype Classes**:
- `ZoneBasedCameraPrototypeView` - Zone-based layout
- `FABSystemCameraPrototypeView` - Floating action buttons
- `TwoStageCameraPrototypeView` - Two-stage workflow
- `CameraStage` - Enum for Two-Stage prototype states

**Dashboard Support**:
- `DashboardView.CameraPrototype` - Enum for prototype selection
- `prototypeView(for:)` - ViewBuilder that returns appropriate prototype
