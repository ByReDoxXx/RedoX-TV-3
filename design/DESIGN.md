---
name: RedoX TV Expressive
colors:
  surface: '#111126'
  surface-dim: '#111126'
  surface-bright: '#37374e'
  surface-container-lowest: '#0c0c21'
  surface-container-low: '#19192f'
  surface-container: '#1d1d33'
  surface-container-high: '#28283e'
  surface-container-highest: '#333349'
  on-surface: '#e2dffd'
  on-surface-variant: '#e5bdba'
  inverse-surface: '#e2dffd'
  inverse-on-surface: '#2e2e45'
  outline: '#ac8885'
  outline-variant: '#5c403d'
  surface-tint: '#ffb3ad'
  primary: '#ffb3ad'
  on-primary: '#68000a'
  primary-container: '#d7232c'
  on-primary-container: '#fff0ee'
  inverse-primary: '#be081e'
  secondary: '#ffb693'
  on-secondary: '#562000'
  secondary-container: '#ed6915'
  on-secondary-container: '#351100'
  tertiary: '#f9bc4b'
  on-tertiary: '#422c00'
  tertiary-container: '#936700'
  on-tertiary-container: '#fff2e2'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdad7'
  primary-fixed-dim: '#ffb3ad'
  on-primary-fixed: '#410004'
  on-primary-fixed-variant: '#930013'
  secondary-fixed: '#ffdbcb'
  secondary-fixed-dim: '#ffb693'
  on-secondary-fixed: '#341000'
  on-secondary-fixed-variant: '#7a3000'
  tertiary-fixed: '#ffdeaa'
  tertiary-fixed-dim: '#f9bc4b'
  on-tertiary-fixed: '#271900'
  on-tertiary-fixed-variant: '#5f4100'
  background: '#111126'
  on-background: '#e2dffd'
  surface-variant: '#333349'
typography:
  display-lg:
    fontFamily: Sora
    fontSize: 56px
    fontWeight: '800'
    lineHeight: 64px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Sora
    fontSize: 36px
    fontWeight: '800'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Sora
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Sora
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Sora
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: 0em
  headline-sm:
    fontFamily: Sora
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: 0em
  title-lg:
    fontFamily: Sora
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: 0.01em
  title-md:
    fontFamily: Sora
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: 0.01em
  body-lg:
    fontFamily: Sora
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.01em
  body-md:
    fontFamily: Sora
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.015em
  body-sm:
    fontFamily: Sora
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-lg:
    fontFamily: Sora
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  label-md:
    fontFamily: Sora
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.04em
  label-sm:
    fontFamily: Sora
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 14px
    letterSpacing: 0.06em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1.5rem
  gutter-tv: 3rem
  margin: 1.5rem
  margin-tv: 4rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

The design system embodies the tension of ignition and refined kinetic control. Built upon the principles of Material Design 3 Expressive, it departs from sterile utility to evoke adrenaline, cinematic depth, and fluid momentum across living room displays, pocket devices, and desktop environments. 

### Brand Personality & Core Values
- **Combustive Energy:** Vibrant, chromatic bursts that guide attention through thermal cues and deliberate, glowing reactions.
- **Cinematic Precision:** Deep visual staging anchored by true-black OLED baselines, allowing media content and critical telemetry to float without competing clutter.
- **Expressive Agility:** Energetic transitions and tactile state morphs that feel natural when driven by a TV remote D-pad, a capacitive touch swipe, or high-precision pointer gestures.

### Aesthetic Paradigm
The visual philosophy pairs **High-Contrast Cinematic Brutalism** with **M3 Expressive Warmth**. Deep obsidian canvases minimize eye fatigue in dim viewing conditions (such as a 10-foot theater setup), while saturated crimson flames and molten amber highlights command hierarchy. Tonal surface containers separate content planes, accented by vibrant kinetic halos and responsive focus outlines instead of generic skeuomorphic shading.

## Colors

> Palette revised on 2026-10-31: the four seeds are measured from the RedoX TV logo (Logo-2, black background); roles are recomputed with the M3 fidelity scheme. See DESIGN-KARARLAR.md.

The color system utilizes a combustion spectrum built over dark architectural surfaces. Contrast requirements honor both standard AA/AAA readability and the high luminosity wash inherent to 10-foot television hardware.

### Palette Architecture
- **Primary (`#D7232C` - Crimson Flame):** The core brand anchor. Used for critical interactive triggers, heroic focus states, playback scrobblers, and live status pulses.
- **Secondary (`#FC7422` - Molten Amber):** High-energy companion accent. Denotes featured metadata, progress completion states, and active category switches.
- **Tertiary (`#FBBE4D` - Incandescent Gold):** Used sparingly for badges, ratings, VIP tiers, and thermal highlights within active gradient maps.
- **Neutral Canvas (`#0B0B20` - Obsidian Void):** The logo's midnight navy. A near-black base that keeps OLED blacks deep while tinting every surface toward the brand.

### Tonal Surface Hierarchy (M3 Surface Containers)
Depth is communicated through brightness stepping rather than pure blur:
- `surface-container-lowest`: `#08090B` — Viewport backdrops, video letterbox buffers.
- `surface-container-low`: `#121418` — Inactive rail navigation, secondary trays.
- `surface-container`: `#181A20` — Default media card backdrops, grouped listings.
- `surface-container-high`: `#22252C` — Overlays, contextual popovers, active modal frames.
- `surface-container-highest`: `#2C3039` — Hover states, input fields, nested tactile surfaces.

### Focus & Kinetic Glow Mechanics
Interactive focus states do not rely solely on border color. Focused elements project an ambient, soft-falloff outer glow (`rgba(216, 33, 49, 0.45)` with a secondary internal highlight of `rgba(237, 150, 80, 0.25)`), creating an illuminated physical presence on distant TV monitors.

## Typography

The design system relies entirely on **Sora**, an expressive geometric sans-serif engineered with wide apertures, structural distinctiveness, and crisp letterforms that remain legible across low-density monitors and high-resolution 4K panels alike.

### Typographic Rhythm & Scaling Rules
- **10-Foot UI (TV Displays):** Headline hierarchy scales upward visually. Labels and metadata prioritize weights `600` and `700` to prevent letterform dropouts against vibrant background art. The minimum allowed text size on TV surfaces is `title-md` (`16px`).
- **Desktop & Web Platforms:** Strict vertical cadence based on a 4px/8px baselines. Body copy favors `body-md` with tracking balanced for medium-density reading.
- **Mobile/Handheld Viewports:** Hero display type utilizes the `-mobile` explicit tokens to prevent single-word line overflows while preserving Sora's visual punch.
- **Expressive Accents:** Numeric content, runtimes, match scores, and metadata timestamps enforce `tnum` (tabular lining figures) within Sora to prevent card layout jitter during live updates.

## Layout & Spacing

Layout geometry follows an adaptable fluid-grid system calibrated around viewport density and user input methods.

### Form Factor Specifications
- **10-Foot UI (Android TV / Big Screen):**
  - Uses an overscan-safe layout with `margin-tv` (`4rem` / 64px) minimum outer bounds.
  - Horizontally scrolling carousels retain active center offsets, ensuring the focused card never clips outside the viewing area.
  - Inter-card gutters utilize `gutter-tv` (`3rem` / 48px) to provide space for focused-state card expansion without overlap collisions.
- **Handheld Devices (Mobile):**
  - Single to dual-column layouts with `1.5rem` outer margins.
  - Bottom navigation bars and gesture sheets anchor reachability zones within the lower thumb-arc.
- **Large Format (Tablet, Desktop - macOS, Windows, Linux):**
  - 12-column dynamic fluid layout with collapsible primary navigation rails.
  - Margins lock to `2.5rem` (`space-xl`), gutters default to `1.5rem` (`gutter`).

### Density & Spatial Rules
1. **Focus Margins:** Any interactive container must maintain at least `space-md` (`1rem`) clear buffer to allow spatial focus rings and glow envelopes to render unclipped.
2. **Component Packing:** Metadata clusters within cards must be grouped tightly using `space-xs` and `space-sm`, reserving `space-lg` for structural domain separation.

## Elevation & Depth

Rather than relying on drop shadows that muddy deep dark modes, the design system implements **Tonal Elevation combined with Chromatic Backlight Flares**.

### Surface Hierarchy & Depth Stacking
Depth is achieved via luminosity gradation across the obsidian continuum:
- **Base Level (0dp):** `surface-container-lowest` — Canvas background.
- **Resting Components (1dp):** `surface-container` — Inactive cards, carousel panels, secondary controls.
- **Floating Overlays (2dp):** `surface-container-high` — App bars, floating action pills, side drawouts.
- **Modals & Dialogs (3dp):** `surface-container-highest` — System dialogs, context action menus.

### Focus Elevation & Kinetic Illumination
When an element receives input focus (via D-pad, keyboard navigation, or pointer hover):
1. **Physical Elevation:** Scale increases dynamically between `1.04x` (desktop/tablet) and `1.08x` (TV) via spring physics.
2. **Combustion Glow:** An multi-tiered outer aura deploys immediately:
   - Primary Ring: Sharp 2px outer outline in `#D7232C`.
   - Secondary Aura: 0px 8px 32px `rgba(216, 33, 49, 0.40)`.
   - Tertiary Bloom: 0px 16px 64px `rgba(237, 150, 80, 0.20)`.
3. **Resting Outlines:** Inactive containers utilize subtle ghost boundaries (`1px solid rgba(255, 255, 255, 0.08)`) to preserve definition against pure black canvas sections without heavy shadowing.

## Shapes

In alignment with Material Design 3 Expressive, shapes are soft, fluid, and intentional. Rigid rectangular geometry is avoided in favor of friendly, dynamic curves that complement the energetic visual theme.

### Geometric Rules
- **Standard Elements (0.5rem / 8px):** Internal input fields, thumbnails, nested mini-badges, metadata chips.
- **Structural Containers (`rounded-lg` / 1rem / 16px):** Primary media presentation cards, dialog frames, bottom sheet panels, context flyouts.
- **Hero Containers (`rounded-xl` / 1.5rem / 24px):** Spotlight cards, featured banner carousels, immersive live event frames.
- **Pill Formats (Full Radius / 9999px):** All primary call-to-action buttons, category selector pills, live status tags, floating scrub handles.

## Components

### Buttons
- **Primary Combustive Button:** Pill-shaped, background filled with `#D7232C`, typography set to `label-lg` in `#FFFFFF`. On TV/Keyboard focus, scales to `1.06x` and gains the primary flame aura.
- **Secondary Glass Button:** Translucent container (`rgba(255, 255, 255, 0.10)`) with a 1px ghost border (`rgba(255, 255, 255, 0.15)`). On focus, transitions background to `#FC7422` with dark foreground text (`#0B0B20`).
- **Icon Action Buttons:** Circular pills (48px × 48px touch/pointer target, 56px × 56px on TV) positioned with centered vector iconography.

### Media Cards (Dynamic Fluid Cards)
- Composed with `rounded-lg` geometry. Inactive state features `surface-container` backing with a 16:9 or 2:3 aspect ratio.
- Artwork incorporates a vertical gradient ramp (`rgba(0, 0, 0, 0)` to `rgba(0, 0, 0, 0.95)`) over the bottom third to guarantee contrast for titles set in `title-md`.
- **D-Pad Focus Interaction:** Card scales to `1.08x`, brings forward title metadata, triggers the kinetic flame glow envelope, and elevates z-index above neighboring shelf items.

### Chips & Pill Tags
- Fully rounded pill containers.
- **Filter Chips:** Inactive background `surface-container-high`; text in `body-sm`. Selected state shifts background to a linear gradient from `#D7232C` to `#FC7422` with text in high-contrast white.
- **Status / Live Badges:** Tiny pill tag using Incandescent Gold (`#FBBE4D`) or Crimson Flame (`#D7232C`) with an embedded pulsating dot indicator.

### Input Fields
- `surface-container-highest` background fill with a resting 1px ghost border.
- Floating label typography adheres to `label-md`.
- Active focus displays a persistent 2px outline in `#FC7422` with a subtle amber surface wash (`rgba(252, 116, 34, 0.05)`).

### Selection Controls (Checkboxes & Radios)
- **Checkboxes:** `rounded-xs` square toggle (4px corner radius). Checked state transitions to a solid `#D7232C` fill with an internal white checkmark.
- **Radio Buttons:** Concentric circles. Selected state renders a deep obsidian center surrounded by an active `#FC7422` ring.

### TV Remote D-Pad Navigation Rails & Lists
- Vertical and horizontal lists support virtualized scrolling.
- Navigation rail stays compressed to iconography until focused, smoothly expanding to reveal labels with an energetic spring curve (`cubic-bezier(0.2, 0.0, 0, 1.0)`).
- Active item displays an asymmetric pill highlight that anchors to the leading screen edge.