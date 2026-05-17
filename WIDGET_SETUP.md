# Widget and Live Activity Setup Guide

This document describes how to set up the WidgetKit extension and Live Activities for the Parabus app.

## Folder Structure

```
parabus/
├── Sources/                          # Main app sources
│   ├── App/
│   ├── Models/
│   ├── Services/
│   │   ├── CacheManager.swift
│   │   ├── WidgetIntegration.swift   # NEW: Widget data sharing
│   │   ├── LiveActivityService.swift # NEW: Live Activity management
│   │   └── ...
│   ├── Views/
│   └── Theme/
│
├── Shared/                           # NEW: Shared between app and widget
│   ├── SharedTypes.swift             # Widget data types
│   └── LiveActivityTypes.swift       # ActivityKit attributes
│
├── ParabusWidget/                    # NEW: Widget extension
│   ├── ParabusWidgetBundle.swift     # Widget bundle entry point
│   ├── MetrobusStatusWidget.swift    # Home Screen widgets
│   ├── MetrobusAccessoryWidget.swift # Lock Screen widgets
│   ├── MetrobusLiveActivity.swift    # Live Activity views
│   ├── Info.plist
│   └── ParabusWidget.entitlements
│
├── Parabus.entitlements              # Main app entitlements
└── Package.swift
```

## Xcode Project Setup

### 1. Add Widget Extension Target

1. In Xcode, select File > New > Target
2. Choose "Widget Extension"
3. Name it "ParabusWidget"
4. Uncheck "Include Configuration App Intent" (we use static configuration)
5. Uncheck "Include Live Activity" (we add it manually)

### 2. Configure App Groups

Both the main app and widget extension need the same App Group:

**Main App Target:**
1. Select the main app target
2. Go to Signing & Capabilities
3. Click "+ Capability" and add "App Groups"
4. Add group: `group.starkji.parabus-cdmx.app`

**Widget Extension Target:**
1. Select the ParabusWidget target
2. Go to Signing & Capabilities
3. Click "+ Capability" and add "App Groups"
4. Add the same group: `group.starkji.parabus-cdmx.app`

### 3. Add Shared Files to Both Targets

The following files must be added to BOTH targets (main app and widget extension):

- `Shared/SharedTypes.swift`
- `Shared/LiveActivityTypes.swift`

In Xcode:
1. Select each file in the Project Navigator
2. In the File Inspector (right panel), check both targets under "Target Membership"

### 4. Configure Info.plist

**Main App Info.plist** - Add:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

**Widget Extension Info.plist** - Already configured in `ParabusWidget/Info.plist`

### 5. Configure Background Modes (Main App)

1. Select the main app target
2. Go to Signing & Capabilities
3. Add "Background Modes" capability
4. Enable:
   - Background fetch
   - Remote notifications (for Live Activity push updates)

## Integration Code

### Update ViewModel to Sync Widget Data

In your `MetrobusViewModel.swift`, add widget sync after data refresh:

```swift
func refreshData() async {
    do {
        let result = try await scraper.fetchStatus()

        // Save to cache AND update widget
        try await cache.saveAndUpdateWidget(result)

        self.lines = result.lines

        // Process Live Activities (iOS 16.2+)
        if #available(iOS 16.2, *) {
            await LiveActivityService.shared.processStatusUpdate(result.lines)
        }
    } catch {
        // Handle error
    }
}
```

### App Delegate Integration

In your app's initialization:

```swift
@main
struct ParabusApp: App {

    init() {
        // Register background refresh
        BackgroundRefreshManager.shared.registerBackgroundTask()

        // Enable automatic Live Activity management (optional)
        if #available(iOS 16.2, *) {
            Task { @MainActor in
                LiveActivityService.shared.startMonitoring()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Widget Families

The implementation supports these widget families:

| Family | Size | Purpose |
|--------|------|---------|
| `.systemSmall` | 2x2 | Worst status + affected line count |
| `.systemMedium` | 4x2 | All 7 lines with status indicators |
| `.accessoryCircular` | Lock Screen circle | Status icon + issue count |
| `.accessoryRectangular` | Lock Screen rectangle | Status summary text |
| `.accessoryInline` | Lock Screen inline | Single line text |

## Live Activity Features

### Dynamic Island Presentations

| View | When Shown |
|------|------------|
| Minimal | Another activity has priority |
| Compact | Normal pill state (leading + trailing) |
| Expanded | Long-press or initial presentation |

### Lock Screen

Full-width banner showing:
- Line number and name
- Current status with icon
- Affected stations list
- Time since disruption started
- Last update time

## Timeline Refresh Strategy

```
Normal conditions:     15 minute refresh
Stale data detected:   5 minute refresh
Lock Screen widgets:   20 minute refresh (less critical)
```

This balances data freshness with battery impact. Widgets get ~40-70 refreshes per day.

## Push Notifications for Live Activities

To update Live Activities via push:

1. Configure push notification entitlements
2. Get push token from `LiveActivityManager.pushTokenString`
3. Send to your server
4. Server sends to APNs with topic: `{bundle-id}.push-type.liveactivity`

Example payload:
```json
{
  "aps": {
    "timestamp": 1702000000,
    "event": "update",
    "content-state": {
      "status": "suspended",
      "affectedStations": ["Insurgentes", "Reforma"],
      "info": "Por manifestacion",
      "updatedAt": "2024-01-15T10:30:00Z"
    },
    "stale-date": 1702000900
  }
}
```

## Testing

### Widget Preview

Use Xcode's Canvas for widget previews. Each widget file includes `#Preview` macros.

### Simulator Testing

1. Build and run the main app
2. Add widget to Home Screen (long-press > Edit Home Screen > +)
3. Data syncs automatically after app refresh

### Live Activity Testing

```swift
#if DEBUG
// In your debug menu or console:
Task {
    await LiveActivityService.shared.createTestActivity()
}
#endif
```

### Background Refresh Simulation

In Xcode Debug menu: Debug > Simulate Background Fetch

Or via command line:
```bash
xcrun simctl spawn booted launchctl debug system/com.apple.springboard -- com.parabus.app.refresh
```

## Troubleshooting

### Widget Shows "No Data"

1. Verify App Group is configured identically on both targets
2. Check that `group.starkji.parabus-cdmx.app` container exists
3. Ensure main app has refreshed data at least once

### Live Activity Not Starting

1. Check `areActivitiesEnabled` returns true
2. Verify `NSSupportsLiveActivities` in Info.plist
3. Check user hasn't disabled Live Activities in Settings

### Push Updates Not Working

1. Verify push token is registered with your server
2. Check APNs topic matches: `{bundle-id}.push-type.liveactivity`
3. Verify push certificate is valid for Live Activities
