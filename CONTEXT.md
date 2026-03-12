# DriveMosaic — Project Context

## What It Is

A macOS disk space analyzer — think DaisyDisk but free (freemium), open source, and distributed independently via GitHub Releases. Treemap visualization, real-time scanning, drill-down navigation, drag-to-delete collector.

**Bundle ID:** `com.blackcloud.DriveMosaic`
**Copyright:** Black Cloud LLC
**License:** MIT
**Repo:** https://github.com/Gh0stsinthemachine/DaisyDiskRepl (may rename to DriveMosaic)

---

## Tech Stack

- **Language:** Swift 6.0, SwiftUI
- **Target:** macOS 14.0+
- **Scanner:** BSD `fts` API via `FileScanner.swift` (low-level, fast)
- **Visualization:** Custom `TreemapCanvasView` using Canvas API (squarified treemap layout)
- **Architecture:** `@Observable` pattern — `AppState` is the root, injected via `.environment()`
- **Distribution:** Ad-hoc signed DMG via `scripts/build.sh`, no App Store (sandbox cripples disk utilities)
- **Licensing:** LemonSqueezy for payment + license key validation, `LicenseManager.swift` handles activation

---

## Revenue Model

**Freemium — $4.99 one-time Pro unlock**

- **Free:** Full scanning, treemap visualization, drill-down, sidebar, detail panel, breadcrumb navigation
- **Pro:** Delete-to-Trash from collector, future: duplicate detection, export reports, custom themes

**Payment platform:** LemonSqueezy (license key API, no custom server needed)
**Test mode:** Keys starting with `DMPRO-` bypass API validation (remove before public release)

---

## Project Structure

```
DaisyDisk Repl/                    ← Project root (legacy folder name)
  DriveMosaic.xcodeproj/
  DriveMosaic/
    App/
      DriveMosaicApp.swift         ← @main entry point, WindowGroup
      AppState.swift               ← Root observable state (scan, nav, collector, license)
      LicenseManager.swift         ← Pro license state, LemonSqueezy API, UserDefaults cache
    Models/
      FileNode.swift               ← Tree node (path, size, children, isDirectory)
      CollectorItem.swift          ← Deletion queue item
    Scanning/
      FileScanner.swift            ← BSD fts scanner, file pruning (50/dir limit)
      ScanCoordinator.swift        ← AsyncStream bridge, progress tracking
      ScanEvent.swift              ← TransferNode (Sendable), scan events
      VolumeDetector.swift         ← Mounted volume detection
      FullDiskAccessChecker.swift  ← FDA permission check
    Visualization/
      TreemapCanvasView.swift      ← Main interactive treemap (hover, click, drag, CMD+Click)
      TreemapLayout.swift          ← Squarified treemap algorithm
      ColorAssigner.swift          ← Stable color assignment per scan
      SunburstCanvasView.swift     ← Alternate viz (not active)
      SunburstLayout.swift / HitTesting / ArcDescriptor
    Views/
      ContentView.swift            ← Main layout orchestrator (breadcrumbs, sidebar, treemap, collector, toolbar)
      DiskSelectorView.swift       ← Welcome screen with volume cards
      CollectorView.swift          ← Bottom bar drag-drop deletion queue
      ProUpgradeView.swift         ← Upgrade sheet (purchase CTA + license key entry)
    Utilities/
      ByteFormatter.swift          ← Human-readable byte formatting
      PolarMath.swift              ← Trig helpers (sunburst)
    Resources/
      Assets.xcassets/             ← App icon (programmatically generated mosaic)
  scripts/
    build.sh                       ← Clean build → sign → DMG → install
    generate_icon.swift            ← CoreGraphics icon generator
  dist/
    DriveMosaic-1.0.dmg           ← Current distributable
```

---

## Key Architecture Decisions

1. **No App Sandbox** — Required for scanning arbitrary filesystem paths. Users grant Full Disk Access manually.
2. **AsyncStream + GCD** — Scanner runs on `DispatchQueue.global(qos: .userInitiated)`, events flow to main actor via AsyncStream. Critical: scanner.scan() is synchronous and MUST be dispatched to a separate thread or it blocks the event consumer.
3. **File pruning** — Directories with 50+ files consolidate excess into a single "N other files" node. Prevents memory blowout on large volumes.
4. **Ad-hoc code signing** — `CODE_SIGN_IDENTITY="-"`. Users right-click > Open to bypass Gatekeeper.
5. **Freemium gate** — Single checkpoint in `AppState.deleteCollectorItems()`. Free users can drag to collector (see value), gate is on the action not the collection.

---

## Deployment

```bash
# Build, sign, create DMG, install
cd "/Users/tomsikler/Library/Mobile Documents/com~apple~CloudDocs/Claude/DaisyDisk Repl"
bash scripts/build.sh

# Quick rebuild + deploy (no DMG)
osascript -e 'quit app "DriveMosaic"' 2>/dev/null; sleep 0.3
rm -rf /tmp/DriveMosaicBuild
xcodebuild -project DriveMosaic.xcodeproj -scheme DriveMosaic -configuration Release -derivedDataPath /tmp/DriveMosaicBuild clean build 2>&1 | grep -E "error:|BUILD|warning:"
rm -rf /Applications/DriveMosaic.app
cp -R /tmp/DriveMosaicBuild/Build/Products/Release/DriveMosaic.app /Applications/DriveMosaic.app
open /Applications/DriveMosaic.app
```

**Critical:** Always `rm -rf /Applications/DriveMosaic.app` before `cp -R` — macOS doesn't overwrite binaries inside existing .app bundles.

---

## Known Issues / Gotchas

- **NSImage Retina scaling:** `lockFocus()` produces 2x pixel dimensions on Retina. Use `sips` for exact sizing.
- **sips + @ in filenames:** `@2x.png` filenames cause sips errors. Copy to /tmp with clean name first.
- **pbxproj file IDs:** Follow the pattern `4A0001...` for file refs, `4B0001...` for build files, `4C0001...` for groups. Sequential hex suffixes.
- **Xcode project has both sunburst and treemap:** Sunburst code is still in the project but not active. Treemap is the shipping visualization.

---

## Roadmap

### v1.0 RC1 (current)
- [x] Treemap visualization with drill-down
- [x] Real-time scan progress (items, elapsed, rate)
- [x] File pruning for large volumes
- [x] Collector drag-to-delete
- [x] Freemium licensing (LemonSqueezy)
- [x] DMG packaging
- [ ] Wire real LemonSqueezy checkout URL (in progress)
- [ ] Remove DMPRO- test bypass
- [ ] Git commit + push
- [ ] GitHub Release with DMG

### v1.1
- [ ] Duplicate file detection (Pro)
- [ ] Export scan reports — CSV/PDF (Pro)
- [ ] Custom color themes (Pro)
- [ ] Rescan button (already in toolbar, needs testing)
- [ ] Sort options in sidebar (by size, name, date)

---

*Last updated: March 2026*
