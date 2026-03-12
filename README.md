# DriveMosaic

A fast, free, native macOS disk space analyzer. See exactly what's eating your storage with a colorful treemap visualization.

**Free and open source** — no subscriptions, no trials, no gimmicks.

## Features

- **Treemap visualization** — colorful mosaic blocks sized proportionally to file/folder sizes
- **Drill-down navigation** — click any folder to zoom in, breadcrumb bar to navigate back
- **Collapsible panels** — sidebar with folder list + detail panel with file info
- **Collector** — drag files to the collector and batch-delete to Trash
- **Finder integration** — CMD+Click any item to reveal it in Finder
- **Fast scanning** — uses BSD `fts` for high-performance filesystem traversal
- **Full Disk Access** — scans your entire drive (with permission), not just your home folder

## Installation

1. Download `DriveMosaic-1.0.dmg` from [Releases](https://github.com/Gh0stsinthemachine/DaisyDiskRepl/releases)
2. Open the DMG and drag **DriveMosaic** to your **Applications** folder
3. Right-click the app → **Open** (required on first launch for unsigned apps)
4. Grant **Full Disk Access** for complete scanning:
   - Open **System Settings** → **Privacy & Security** → **Full Disk Access**
   - Click the **+** button and add **DriveMosaic**

## Build from Source

Requires Xcode 16+ and macOS 14.0 (Sonoma) or later.

```bash
git clone https://github.com/Gh0stsinthemachine/DaisyDiskRepl.git
cd "DaisyDisk Repl"
./scripts/build.sh
```

The build script compiles, creates a DMG in `dist/`, and installs to `/Applications`.

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (arm64)

## License

MIT License — Copyright (c) 2026 Black Cloud LLC
