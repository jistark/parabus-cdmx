# Parabus Design System
## iOS 26 Transit Status App for Metrobus CDMX

Version: 1.0
Last Updated: 2025-12-06
Target: iOS 26+ with Liquid Glass

---

## Table of Contents
1. [Design Philosophy](#design-philosophy)
2. [Navigation Architecture](#navigation-architecture)
3. [Color System](#color-system)
4. [Typography Scale](#typography-scale)
5. [Spacing System](#spacing-system)
6. [Component Library](#component-library)
7. [UI States](#ui-states)
8. [Accessibility](#accessibility)
9. [Widgets](#widgets)
10. [Live Activities](#live-activities)
11. [iOS 26 Liquid Glass](#ios-26-liquid-glass)

---

## 1. Design Philosophy

### Core Principles

**Glanceable First**
- Status visible in less than 1 second
- Color + icon = immediate understanding
- No cognitive load for "is my line OK?"

**Transit-Optimized Hierarchy**
1. Primary: Overall system status (all clear vs. issues)
2. Secondary: Which lines are affected
3. Tertiary: Station-level details

**Native iOS Experience**
- Embrace iOS 26 Liquid Glass where appropriate
- SF Symbols for all iconography
- System colors with semantic meaning
- Haptic feedback on interactions

---

## 2. Navigation Architecture

### Tab Structure (4 tabs)

```
TabView {
    StatusTab()      // Home - system overview
    AlertsTab()      // All active disruptions
    FavoritesTab()   // User's saved lines (future)
    SettingsTab()    // Preferences
}
```

#### Tab Bar Configuration

```swift
TabView {
    StatusView()
        .tabItem {
            Label("Estado", systemImage: "tram.fill")
        }
        .badge(activeDisruptionCount > 0 ? activeDisruptionCount : nil)

    AlertsView()
        .tabItem {
            Label("Alertas", systemImage: "exclamationmark.triangle.fill")
        }
        .badge(alertCount)

    FavoritesView()
        .tabItem {
            Label("Mis Lineas", systemImage: "star.fill")
        }

    SettingsView()
        .tabItem {
            Label("Ajustes", systemImage: "gearshape.fill")
        }
}
.tint(.accentColor)
```

### Navigation Flow

```
StatusTab
    |-- LineDetailSheet (presented as .sheet)
    |     |-- IncidentDetailView (push)
    |     |-- StationListView (push)
    |
    |-- MaintenanceDetailSheet (presented as .sheet)

AlertsTab
    |-- AlertDetailView (push navigation)
    |     |-- LineDetailSheet (presented as .sheet)

FavoritesTab
    |-- LineDetailSheet (presented as .sheet)
    |-- EditFavoritesView (push navigation)

SettingsTab
    |-- CommuteTimes (push)
    |-- NotificationSettings (push)
    |-- AboutView (push)
```

---

## 3. Color System

### Status Colors (Semantic)

```swift
enum StatusColors {
    // MARK: - Status Indicators

    /// Service operating normally
    /// Light: #34C759 | Dark: #30D158
    static let good = Color.green

    /// Partial service / intervention / maintenance
    /// Light: #FF9500 | Dark: #FF9F0A
    static let warning = Color.orange

    /// Service suspended / major delay
    /// Light: #FF3B30 | Dark: #FF453A
    static let critical = Color.red

    /// Unknown status / stale data
    static let unknown = Color.secondary

    // MARK: - Usage

    static func color(for status: ServiceStatus) -> Color {
        switch status {
        case .regular: return good
        case .intervention: return warning
        case .suspended: return critical
        case .delayed: return critical  // Delays are urgent
        case .unknown: return unknown
        }
    }
}
```

### Line Brand Colors (Official Metrobus)

```swift
enum LineColors {
    /// Line 1 - Insurgentes (Red)
    static let line1 = Color(red: 0.83, green: 0.18, blue: 0.18) // #D42E2E

    /// Line 2 - Eje 4 Sur (Purple)
    static let line2 = Color(red: 0.48, green: 0.18, blue: 0.56) // #7A2E8F

    /// Line 3 - Eje 1 Poniente (Green)
    static let line3 = Color(red: 0.13, green: 0.55, blue: 0.13) // #228B22

    /// Line 4 - Buenavista-Aeropuerto (Gold)
    static let line4 = Color(red: 0.96, green: 0.65, blue: 0.14) // #F5A623

    /// Line 5 - Eje 3 Oriente (Blue)
    static let line5 = Color(red: 0.00, green: 0.48, blue: 0.65) // #007AA6

    /// Line 6 - Aragon-El Rosario (Magenta)
    static let line6 = Color(red: 0.80, green: 0.00, blue: 0.47) // #CC0078

    /// Line 7 - Indios Verdes-Campo Marte (Teal)
    static let line7 = Color(red: 0.00, green: 0.60, blue: 0.40) // #009966

    static func color(for lineNumber: String) -> Color {
        switch lineNumber {
        case "1": return line1
        case "2": return line2
        case "3": return line3
        case "4": return line4
        case "5": return line5
        case "6": return line6
        case "7": return line7
        default: return Color.gray
        }
    }
}
```

### Surface Colors

```swift
enum SurfaceColors {
    // MARK: - Backgrounds

    /// Main app background
    static let background = Color(.systemGroupedBackground)

    /// Card/cell background
    static let cardBackground = Color(.secondarySystemGroupedBackground)

    /// Elevated surface (sheets, popovers)
    static let elevated = Color(.tertiarySystemGroupedBackground)

    // MARK: - Material Opacities

    /// Subtle tint for cards (0.06)
    static let tintSubtle: Double = 0.06

    /// Light tint for status cards (0.10)
    static let tintLight: Double = 0.10

    /// Medium tint for emphasis (0.15)
    static let tintMedium: Double = 0.15

    /// Border opacity (0.20)
    static let borderOpacity: Double = 0.20

    /// Strong border for status (0.40)
    static let borderStrong: Double = 0.40
}
```

### Dark Mode Considerations

| Element | Light Mode | Dark Mode |
|---------|-----------|-----------|
| Status green | #34C759 | #30D158 |
| Status orange | #FF9500 | #FF9F0A |
| Status red | #FF3B30 | #FF453A |
| Card background | systemBackground | secondarySystemBackground |
| Text primary | .black | .white |
| Text secondary | .secondary | .secondary |

---

## 4. Typography Scale

### Type Styles (SF Pro with Dynamic Type)

```swift
enum ParabusTypography {
    // MARK: - Headers

    /// Large navigation title
    /// SF Pro Bold, 34pt base
    static let largeTitle = Font.largeTitle

    /// Section headers
    /// SF Pro Semibold, 22pt base
    static let title = Font.title

    /// Card titles, line names
    /// SF Pro Semibold, 20pt base
    static let title2 = Font.title2.weight(.semibold)

    /// Subsection headers
    /// SF Pro Semibold, 17pt base
    static let headline = Font.headline

    // MARK: - Body

    /// Primary body text
    /// SF Pro Regular, 17pt base
    static let body = Font.body

    /// Secondary information
    /// SF Pro Regular, 15pt base
    static let subheadline = Font.subheadline

    // MARK: - Supporting

    /// Status labels, timestamps
    /// SF Pro Regular, 12pt base
    static let caption = Font.caption

    /// Tertiary info, badges
    /// SF Pro Regular, 11pt base
    static let caption2 = Font.caption2

    // MARK: - Emphasis Variants

    static let bodyMedium = Font.body.weight(.medium)
    static let captionMedium = Font.caption.weight(.medium)
    static let caption2Bold = Font.caption2.weight(.bold)
}
```

### Usage Guidelines

| Context | Style | Weight |
|---------|-------|--------|
| App title | largeTitle | bold |
| Section header | headline | semibold |
| Line name (card) | subheadline | semibold |
| Status text | caption | medium |
| Station name | body | regular |
| Timestamp | caption2 | regular |
| Badge number | title | bold |

### Dynamic Type Support

```swift
// ALWAYS use @ScaledMetric for custom sizes
@ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 48
@ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 16

// Test at these sizes:
// - Default (100%)
// - Large (135%)
// - Accessibility XXL (310%)
// - Accessibility XXXL (390%)
```

---

## 5. Spacing System

### 8pt Grid

```swift
enum Spacing {
    /// 4pt - Tight spacing (icon-to-text in badges)
    static let xxs: CGFloat = 4

    /// 8pt - Compact spacing (between related elements)
    static let xs: CGFloat = 8

    /// 12pt - Default component spacing
    static let sm: CGFloat = 12

    /// 16pt - Section padding, card insets
    static let md: CGFloat = 16

    /// 20pt - Screen edge padding
    static let lg: CGFloat = 20

    /// 24pt - Section separation
    static let xl: CGFloat = 24

    /// 32pt - Major section breaks
    static let xxl: CGFloat = 32
}
```

### Layout Constants

```swift
enum Layout {
    // MARK: - Touch Targets

    /// Minimum touch target (Apple HIG)
    static let minTouchTarget: CGFloat = 44

    // MARK: - Corner Radii

    /// Small elements (badges, pills)
    static let cornerRadiusSmall: CGFloat = 8

    /// Cards, tiles
    static let cornerRadiusMedium: CGFloat = 14

    /// Sheets, large containers
    static let cornerRadiusLarge: CGFloat = 20

    // MARK: - Component Sizes

    /// Line badge small
    static let badgeSmall: CGFloat = 32

    /// Line badge regular
    static let badgeRegular: CGFloat = 48

    /// Line badge large
    static let badgeLarge: CGFloat = 56

    // MARK: - Grid

    /// Grid columns for lines (iPhone)
    static let lineGridColumns = 4

    /// Grid columns for lines (iPad)
    static let lineGridColumnsWide = 7
}
```

### Screen Layout

```
+------------------------------------------+
|  Safe Area Top (Dynamic)                 |
+------------------------------------------+
|  Navigation Bar (44pt + title)           |
+------------------------------------------+
|                                          |
|  +-[20pt padding]--------------------+   |
|  |                                   |   |
|  |  Section Header                   |   |
|  |  [12pt spacing]                   |   |
|  |  Content                          |   |
|  |                                   |   |
|  +-----------------------------------+   |
|  [24pt section spacing]                  |
|  +-[20pt padding]--------------------+   |
|  |  Next Section                     |   |
|  +-----------------------------------+   |
|                                          |
+------------------------------------------+
|  Tab Bar (49pt + Safe Area Bottom)       |
+------------------------------------------+
```

---

## 6. Component Library

### 6.1 StatusBadge

Visual indicator of service status.

```swift
struct StatusBadge: View {
    let status: ServiceStatus
    var style: Style = .compact

    enum Style {
        case compact    // Icon only, pill shape
        case expanded   // Icon + text, pill shape
        case inline     // Icon + text, no background
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: status.icon)
                .font(style == .compact ? .footnote : .subheadline)
                .symbolEffect(
                    .pulse,
                    options: .repeating,
                    isActive: status.isPulsing
                )

            if style != .compact {
                Text(status.displayText)
                    .font(.subheadline.weight(.medium))
            }
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, style == .compact ? 10 : 14)
        .padding(.vertical, style == .compact ? 6 : 10)
        .frame(minHeight: Layout.minTouchTarget)
        .background(
            status.color.opacity(SurfaceColors.tintMedium),
            in: Capsule()
        )
        .accessibilityLabel(status.accessibilityLabel)
    }
}
```

**SF Symbols:**
| Status | Symbol | Animation |
|--------|--------|-----------|
| Regular | `checkmark.circle.fill` | None |
| Intervention | `wrench.and.screwdriver.fill` | None |
| Delayed | `clock.badge.exclamationmark` | Pulse |
| Suspended | `xmark.octagon.fill` | Pulse |
| Unknown | `questionmark.circle.fill` | None |

---

### 6.2 LineBadge

Official line number badge with brand color.

```swift
struct LineBadge: View {
    let lineNumber: String
    let transportType: TransportType
    var size: Size = .regular

    enum Size {
        case small   // 32pt - lists, compact UI
        case regular // 48pt - cards, banners
        case large   // 56pt - detail headers

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .regular: return 48
            case .large: return 56
            }
        }
    }

    var body: some View {
        // Prefer official asset if available
        if let officialImage = loadOfficialIcon() {
            officialImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.dimension, height: size.dimension)
        } else {
            // Fallback: colored circle with number
            ZStack {
                Circle()
                    .fill(LineColors.color(for: lineNumber).gradient)

                Text(lineNumber)
                    .font(size.font)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .frame(width: size.dimension, height: size.dimension)
            .shadow(
                color: LineColors.color(for: lineNumber).opacity(0.3),
                radius: 4,
                y: 2
            )
        }
    }
}
```

**Accessibility:**
```swift
.accessibilityLabel("Metrobus Linea \(lineNumber)")
```

---

### 6.3 LineCard

Tappable card showing line status in the main grid.

```swift
struct LineCard: View {
    let line: LineStatus
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 48

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.xs) {
                // Line badge
                LineBadge(
                    lineNumber: line.lineNumber,
                    transportType: line.transportType,
                    size: .regular
                )
                .frame(width: badgeSize, height: badgeSize)

                // Line name
                Text("Linea \(line.lineNumber)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Status pill
                StatusPill(status: line.status, incidentCount: line.incidentCount)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.sm)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium))
            .overlay(cardBorder)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.lineName), \(line.status.rawValue)")
        .accessibilityHint(line.hasIssues ? "Toca para ver detalles" : "Servicio normal")
    }

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            Color(white: colorScheme == .dark ? 0.15 : 0.95)
        } else if line.hasIssues {
            StatusColors.color(for: line.status)
                .opacity(SurfaceColors.tintSubtle)
                .background(.ultraThinMaterial)
        } else {
            Color.clear.background(.ultraThinMaterial)
        }
    }
}
```

**Layout Specifications:**
- Card width: Flexible (grid-based)
- Card min-height: 100pt
- Padding: 16pt vertical, 12pt horizontal
- Corner radius: 14pt continuous
- Border: 1px when normal, 1.5px when issue

---

### 6.4 AlertRow

List row for the Alerts tab showing a disruption.

```swift
struct AlertRow: View {
    let line: LineStatus
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 48

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                // Line badge
                LineBadge(
                    lineNumber: line.lineNumber,
                    transportType: line.transportType,
                    size: .regular
                )
                .frame(width: badgeSize, height: badgeSize)

                // Content
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(line.lineName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(alertSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Status + disclosure
                HStack(spacing: Spacing.xs) {
                    StatusBadge(status: line.status, style: .compact)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 64)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
    }

    private var alertSummary: String {
        if line.affectedStations.isEmpty {
            return line.status.rawValue
        }
        if line.affectedStations.count == 1 {
            return line.affectedStations[0]
        }
        return "\(line.affectedStations[0]) y \(line.affectedStations.count - 1) mas"
    }
}
```

---

### 6.5 MaintenanceCard

Card showing scheduled station closure.

```swift
struct MaintenanceCard: View {
    let closure: ScheduledClosure
    let isActiveToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Header row
            HStack(spacing: Spacing.sm) {
                // Line indicator
                LineBadge(
                    lineNumber: closure.lineNumber,
                    transportType: .metrobus,
                    size: .small
                )

                // Station name
                Text(closure.stationName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                // Active indicator
                if isActiveToday {
                    Text("Hoy")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                }
            }

            // Details
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                // Direction
                Label(closure.direction.displayName, systemImage: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Reason
                Label(closure.reason.displayName, systemImage: "wrench.and.screwdriver.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Period
                Label(closure.closurePeriod, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 40) // Align with text after badge
        }
        .padding(Spacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium))
    }
}
```

---

### 6.6 StatusHeroCard (All-Clear State)

Prominent card when all lines are operating normally.

```swift
struct StatusHeroCard: View {
    let lastUpdated: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .symbolEffect(
                    .bounce,
                    options: .nonRepeating,
                    isActive: !reduceMotion
                )

            // Message
            Text("Todo en orden")
                .font(.title2.weight(.semibold))

            Text("Las 7 lineas operando normal")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Last updated
            Text("Actualizado \(lastUpdated, style: .relative)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.1), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusLarge))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Todas las lineas operando con normalidad")
    }
}
```

---

## 7. UI States

### 7.1 Loading State (Skeleton)

```swift
struct LoadingSkeletonView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Header skeleton
            HStack {
                SkeletonRectangle(width: 120, height: 20)
                Spacer()
                SkeletonRectangle(width: 80, height: 14)
            }
            .padding(.horizontal, Spacing.lg)

            // Grid skeleton
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 4),
                spacing: Spacing.sm
            ) {
                ForEach(0..<7, id: \.self) { _ in
                    SkeletonCard()
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .redacted(reason: .placeholder)
        .shimmering()  // Custom shimmer modifier
    }
}

struct SkeletonCard: View {
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Circle()
                .frame(width: 48, height: 48)

            RoundedRectangle(cornerRadius: 4)
                .frame(width: 50, height: 12)

            Capsule()
                .frame(width: 40, height: 20)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium))
    }
}
```

### 7.2 Error State

```swift
struct ErrorStateView: View {
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Sin conexion", systemImage: "wifi.slash")
        } description: {
            Text("No pudimos obtener el estado del servicio.\nVerifica tu conexion a internet.")
        } actions: {
            Button {
                onRetry()
            } label: {
                Label("Reintentar", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
```

**VoiceOver:**
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("Error de conexion. No pudimos obtener el estado del servicio.")
.accessibilityHint("Toca el boton reintentar para volver a cargar")
```

### 7.3 Empty State

```swift
struct EmptyStateView: View {
    let onRefresh: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Sin informacion", systemImage: "tray")
        } description: {
            Text("No hay datos de servicio disponibles.\nDesliza hacia abajo para actualizar.")
        } actions: {
            Button {
                onRefresh()
            } label: {
                Label("Actualizar", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }
}
```

### 7.4 Stale Data Indicator

Shows when cached data is older than 15 minutes.

```swift
struct StaleDataBanner: View {
    let lastUpdated: Date
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text("Datos de hace \(lastUpdated, style: .relative)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Actualizar", action: onRefresh)
                .font(.caption.weight(.medium))
                .foregroundStyle(.accentColor)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusSmall))
    }
}
```

---

## 8. Accessibility

### 8.1 VoiceOver Labels

```swift
// Status Badge
.accessibilityLabel(status.rawValue)  // "Servicio Regular", "Servicio Suspendido"

// Line Badge
.accessibilityLabel("Metrobus Linea \(lineNumber)")

// Line Card
.accessibilityLabel("\(line.lineName), \(line.status.rawValue)")
.accessibilityHint(line.hasIssues ? "Toca para ver detalles" : "")

// Alert Row
.accessibilityLabel("\(line.lineName), \(alertSummary)")
.accessibilityHint("Toca para ver detalles del incidente")

// Maintenance Card
.accessibilityLabel("Estacion \(closure.stationName) en Linea \(closure.lineNumber)")
.accessibilityValue("\(closure.reason.displayName), \(closure.closurePeriod)")
```

### 8.2 Dynamic Type Support

Every component must scale properly:

```swift
// BAD - Fixed sizes
.frame(width: 48, height: 48)

// GOOD - Scaled sizes
@ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 48
.frame(width: badgeSize, height: badgeSize)

// Minimum readable at XXXL
.minimumScaleFactor(0.7)
.lineLimit(nil)  // Allow text wrapping
```

### 8.3 Reduce Motion

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// Disable symbol effects
.symbolEffect(.pulse, isActive: shouldPulse && !reduceMotion)

// Use instant animations
.animation(reduceMotion ? .none : .spring(response: 0.3))
```

### 8.4 Reduce Transparency

```swift
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

@ViewBuilder
private var cardBackground: some View {
    if reduceTransparency {
        // Solid opaque background
        Color(.secondarySystemGroupedBackground)
    } else {
        // Material with tint
        statusColor.opacity(0.1)
            .background(.ultraThinMaterial)
    }
}
```

### 8.5 Contrast Requirements

| Element | Minimum Ratio |
|---------|--------------|
| Body text | 4.5:1 |
| Large text (18pt+) | 3:1 |
| UI components | 3:1 |
| Focus indicators | 3:1 |

**Status colors pass at all sizes on both light and dark backgrounds.**

### 8.6 Accessibility Checklist

- [ ] All interactive elements have 44x44pt minimum touch target
- [ ] All images have accessibilityLabel or are decorative
- [ ] Status is conveyed by icon + color (never color alone)
- [ ] VoiceOver navigation is logical (top-to-bottom, left-to-right)
- [ ] Dynamic Type scales to accessibility sizes without truncation
- [ ] Reduce Motion disables all non-essential animations
- [ ] Reduce Transparency provides solid backgrounds
- [ ] No information conveyed by color alone

---

## 9. Widgets

### 9.1 Small Widget (systemSmall)

Shows status of favorite line or overall status.

```
+---------------------------+
|  [Status Icon]    [Count] |
|                           |
|  "1 linea afectada"       |
|  Retraso                  |
|  hace 5 min               |
+---------------------------+
```

```swift
struct SmallWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Header
            HStack {
                Image(systemName: data.worstStatus.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(data.worstStatus.color)

                Spacer()

                if !data.allClear {
                    Text("\(data.affectedLinesCount)")
                        .font(.title.weight(.bold))
                        .foregroundStyle(data.worstStatus.color)
                }
            }

            Spacer()

            // Status
            Text(statusTitle)
                .font(.headline)
                .lineLimit(2)

            Text(statusSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Timestamp
            Text(data.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

### 9.2 Medium Widget (systemMedium)

Shows all 7 lines at a glance.

```
+-----------------------------------------------+
|  Metrobus CDMX                  [Stale?] 9:30 |
|                                               |
|  [1] [2] [3] [4] [5] [6] [7]                  |
|   v   !   v   x   v   v   v                   |
|                                               |
|  [v] Todas las lineas operando normal         |
+-----------------------------------------------+
```

```swift
struct MediumWidgetView: View {
    let data: WidgetData
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                Text("Metrobus CDMX")
                    .font(.headline)

                Spacer()

                if data.isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

                Text(data.updatedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Line grid
            LazyVGrid(columns: columns, spacing: Spacing.xs) {
                ForEach(sortedLines) { line in
                    WidgetLineBadge(line: line)
                }
            }

            // Summary
            HStack {
                Image(systemName: data.allClear ? "checkmark.circle.fill" : data.worstStatus.icon)
                    .foregroundStyle(data.allClear ? .green : data.worstStatus.color)

                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

### 9.3 Accessory Widgets (Lock Screen)

Circular and rectangular Lock Screen widgets.

```swift
// Accessory Circular - Shows worst status icon
struct AccessoryCircularView: View {
    let data: WidgetData

    var body: some View {
        Gauge(value: 0.0) {
            Image(systemName: data.worstStatus.icon)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(data.worstStatus.color)
    }
}

// Accessory Rectangular - Compact status
struct AccessoryRectangularView: View {
    let data: WidgetData

    var body: some View {
        HStack {
            Image(systemName: "tram.fill")

            VStack(alignment: .leading) {
                Text("Metrobus")
                    .font(.headline)

                Text(data.allClear ? "Normal" : "\(data.affectedLinesCount) alertas")
                    .font(.caption)
            }
        }
    }
}
```

---

## 10. Live Activities

### 10.1 Attributes

```swift
struct MetrobusDisruptionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        let status: String
        let statusSeverity: Int  // 0-4 scale
        let affectedStations: [String]
        let additionalInfo: String?
        let updatedAt: Date

        var statusIcon: String {
            switch statusSeverity {
            case 4: return "xmark.octagon.fill"
            case 3: return "wrench.and.screwdriver.fill"
            case 2: return "clock.badge.exclamationmark"
            default: return "checkmark.circle.fill"
            }
        }

        var statusColor: Color {
            switch statusSeverity {
            case 4: return .red
            case 3: return .orange
            case 2: return .red
            default: return .green
            }
        }
    }

    let lineNumber: String
    let lineName: String
    let startedAt: Date
}
```

### 10.2 Dynamic Island

**Compact View (Pill):**
```
[2]  [!] Obra
```

**Expanded View:**
```
+----------------------------------------+
|  [2]              [!]                  |
|        Linea 2                         |
|----------------------------------------|
|  [pin] La Joya, Iztacalco              |
|  [hourglass] hace 30 min    Manten...  |
+----------------------------------------+
```

### 10.3 Lock Screen Banner

```
+------------------------------------------+
|  [2]   Linea 2              [Obra] pill  |
|        La Joya, Iztacalco                |
|        Por mantenimiento                 |
|  [clock] hace 30 min       Act. 9:45    |
+------------------------------------------+
```

---

## 11. iOS 26 Liquid Glass

### When to Apply

**DO use Liquid Glass:**
- Navigation bar (automatic with `.toolbarBackgroundVisibility(.visible)`)
- Tab bar (automatic)
- Cards with status information
- Floating action buttons
- Sheets and modals

**DON'T use Liquid Glass:**
- Every single element (over-application)
- Text backgrounds (reduces readability)
- Small icons or badges
- Within scrolling content excessively

### Implementation

```swift
// Navigation bar glass effect (iOS 26+)
NavigationStack {
    ContentView()
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
}

// Card with glass background
VStack { ... }
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))

// Glass button
Button(action: {}) {
    Label("Action", systemImage: "plus")
}
.glassBackgroundEffect()

// Conditional for Reduce Transparency
@ViewBuilder
var cardBackground: some View {
    if reduceTransparency {
        Color(.secondarySystemBackground)
    } else {
        Color.clear.background(.ultraThinMaterial)
    }
}
```

### Material Hierarchy

| Material | Blur | Use Case |
|----------|------|----------|
| `.ultraThinMaterial` | Minimal | Cards over content |
| `.thinMaterial` | Light | Toolbars, overlays |
| `.regularMaterial` | Medium | Sheets, sidebars |
| `.thickMaterial` | Heavy | Modals, alerts |
| `.ultraThickMaterial` | Maximum | Rare, high contrast needs |

### Testing Requirements

1. Test with "Reduce Transparency" ON
2. Test in both light and dark mode
3. Verify text readability over glass
4. Check contrast ratios with glass backgrounds
5. Ensure status colors remain distinguishable

---

## Appendix A: SF Symbols Reference

### Status Icons
| Symbol | Usage |
|--------|-------|
| `checkmark.circle.fill` | Normal service |
| `wrench.and.screwdriver.fill` | Intervention/maintenance |
| `clock.badge.exclamationmark` | Delays |
| `xmark.octagon.fill` | Suspended |
| `questionmark.circle.fill` | Unknown |
| `exclamationmark.triangle.fill` | Warning/alert |

### Transit Icons
| Symbol | Usage |
|--------|-------|
| `tram.fill` | Metrobus (generic) |
| `bus.fill` | Bus service |
| `figure.roll` | Accessibility/elevator |
| `mappin.and.ellipse` | Stations |
| `arrow.left.arrow.right` | Directions |

### UI Icons
| Symbol | Usage |
|--------|-------|
| `chevron.right` | Disclosure |
| `arrow.clockwise` | Refresh |
| `gearshape.fill` | Settings |
| `star.fill` | Favorites |
| `calendar` | Schedule |
| `clock` | Time |
| `wifi.slash` | No connection |

---

## Appendix B: Animation Specs

### Standard Animations

```swift
// Card appear/disappear
.animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)

// Status change
.animation(.easeInOut(duration: 0.25), value: status)

// List reorder
.animation(.spring(response: 0.4), value: items)

// Tab switch
// System default

// Sheet present
// .presentationDetents([.medium, .large])
// System spring

// Pull-to-refresh
// System default
```

### Symbol Effects

```swift
// Pulse for urgent status
.symbolEffect(.pulse, options: .repeating, isActive: isUrgent)

// Bounce on success
.symbolEffect(.bounce, options: .nonRepeating)

// Replace on status change
.contentTransition(.symbolEffect(.replace))
```

### Reduce Motion Alternatives

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// Instead of bounce, use opacity
.opacity(reduceMotion ? 1 : (isAppearing ? 1 : 0))

// Instead of spring, use no animation
.animation(reduceMotion ? nil : .spring())
```

---

## Appendix C: Localization Keys

```swift
// Status
"status.regular" = "Servicio Regular";
"status.intervention" = "Intervencion en la estacion";
"status.delayed" = "Servicio con Retraso";
"status.suspended" = "Servicio Suspendido";
"status.unknown" = "Estado Desconocido";

// UI
"tab.status" = "Estado";
"tab.alerts" = "Alertas";
"tab.favorites" = "Mis Lineas";
"tab.settings" = "Ajustes";

// Messages
"allClear.title" = "Todo en orden";
"allClear.subtitle" = "Las 7 lineas operando normal";
"error.noConnection" = "Sin conexion";
"error.tryAgain" = "Reintentar";
"staleData.message" = "Datos desactualizados";

// Accessibility
"a11y.line" = "Linea %@";
"a11y.status" = "Estado: %@";
"a11y.tapForDetails" = "Toca para ver detalles";
```

---

*Document generated for Parabus iOS development team.*
*Reference: Apple Human Interface Guidelines 2024, iOS 26 SDK*
