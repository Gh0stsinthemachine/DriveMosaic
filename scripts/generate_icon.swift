#!/usr/bin/env swift

import Foundation
import CoreGraphics
import AppKit

// DriveMosaic App Icon Generator
// Renders a stylized treemap/mosaic pattern inside a macOS rounded-rect icon shape

let masterSize = 1024

// Output directory
let projectRoot = ProcessInfo.processInfo.arguments.count > 1
    ? ProcessInfo.processInfo.arguments[1]
    : FileManager.default.currentDirectoryPath
let iconsetPath = "\(projectRoot)/DriveMosaic/Resources/Assets.xcassets/AppIcon.appiconset"

// Icon sizes needed for macOS
let iconSizes: [(size: Int, scale: Int, filename: String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]

// Colors for the mosaic blocks — vibrant, matching the app's treemap aesthetic
struct BlockColor {
    let r: CGFloat, g: CGFloat, b: CGFloat
}

let mosaicColors: [BlockColor] = [
    BlockColor(r: 0.90, g: 0.35, b: 0.25),  // Warm red
    BlockColor(r: 0.95, g: 0.55, b: 0.20),  // Orange
    BlockColor(r: 0.85, g: 0.75, b: 0.20),  // Gold
    BlockColor(r: 0.30, g: 0.75, b: 0.45),  // Green
    BlockColor(r: 0.25, g: 0.60, b: 0.85),  // Blue
    BlockColor(r: 0.55, g: 0.35, b: 0.80),  // Purple
    BlockColor(r: 0.80, g: 0.30, b: 0.55),  // Magenta
    BlockColor(r: 0.40, g: 0.80, b: 0.75),  // Teal
    BlockColor(r: 0.70, g: 0.50, b: 0.30),  // Brown
    BlockColor(r: 0.55, g: 0.70, b: 0.25),  // Lime
    BlockColor(r: 0.35, g: 0.45, b: 0.70),  // Steel blue
    BlockColor(r: 0.85, g: 0.45, b: 0.55),  // Rose
]

// A treemap block definition
struct Block {
    let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat
    let colorIndex: Int
}

// Generate treemap-like blocks that fill a square canvas
func generateMosaicBlocks(size: CGFloat) -> [Block] {
    var blocks: [Block] = []

    // Manually define a visually appealing treemap layout
    // These proportions create a mosaic that looks like a disk analysis
    let gap: CGFloat = size * 0.008  // Small gap between blocks
    let inset: CGFloat = size * 0.12  // Inset from icon edge for rounded rect
    let s = size - inset * 2  // Available space
    let ox = inset  // Origin x
    let oy = inset  // Origin y

    // Large block top-left (dominant "folder")
    blocks.append(Block(x: ox, y: oy, w: s * 0.52 - gap, h: s * 0.45 - gap, colorIndex: 4))

    // Medium block top-right
    blocks.append(Block(x: ox + s * 0.52, y: oy, w: s * 0.48, h: s * 0.28 - gap, colorIndex: 0))

    // Small block below top-right
    blocks.append(Block(x: ox + s * 0.52, y: oy + s * 0.28, w: s * 0.25 - gap, h: s * 0.17 - gap, colorIndex: 5))
    blocks.append(Block(x: ox + s * 0.77, y: oy + s * 0.28, w: s * 0.23, h: s * 0.17 - gap, colorIndex: 1))

    // Middle row
    blocks.append(Block(x: ox, y: oy + s * 0.45, w: s * 0.35 - gap, h: s * 0.25 - gap, colorIndex: 3))
    blocks.append(Block(x: ox + s * 0.35, y: oy + s * 0.45, w: s * 0.30 - gap, h: s * 0.25 - gap, colorIndex: 7))
    blocks.append(Block(x: ox + s * 0.65, y: oy + s * 0.45, w: s * 0.35, h: s * 0.15 - gap, colorIndex: 2))
    blocks.append(Block(x: ox + s * 0.65, y: oy + s * 0.60, w: s * 0.18 - gap, h: s * 0.10 - gap, colorIndex: 8))
    blocks.append(Block(x: ox + s * 0.83, y: oy + s * 0.60, w: s * 0.17, h: s * 0.10 - gap, colorIndex: 10))

    // Bottom row
    blocks.append(Block(x: ox, y: oy + s * 0.70, w: s * 0.22 - gap, h: s * 0.30, colorIndex: 6))
    blocks.append(Block(x: ox + s * 0.22, y: oy + s * 0.70, w: s * 0.28 - gap, h: s * 0.30, colorIndex: 9))
    blocks.append(Block(x: ox + s * 0.50, y: oy + s * 0.70, w: s * 0.50, h: s * 0.17 - gap, colorIndex: 11))
    blocks.append(Block(x: ox + s * 0.50, y: oy + s * 0.87, w: s * 0.30 - gap, h: s * 0.13, colorIndex: 4))
    blocks.append(Block(x: ox + s * 0.80, y: oy + s * 0.87, w: s * 0.20, h: s * 0.13, colorIndex: 0))

    return blocks
}

func renderIcon(size: Int) -> NSImage? {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))

    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return nil
    }

    // Dark background
    ctx.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 1.0))
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

    // macOS icon rounded rect mask
    let iconRect = CGRect(x: s * 0.04, y: s * 0.04, width: s * 0.92, height: s * 0.92)
    let cornerRadius = s * 0.185  // macOS icon corner radius
    let iconPath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Fill the rounded rect with the dark background
    ctx.saveGState()
    ctx.addPath(iconPath)
    ctx.clip()

    ctx.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 1.0))
    ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

    // Draw mosaic blocks
    let blocks = generateMosaicBlocks(size: s)

    for block in blocks {
        let color = mosaicColors[block.colorIndex]
        let rect = CGRect(x: block.x, y: block.y, width: block.w, height: block.h)
        let blockRadius = s * 0.012  // Slight rounding on blocks
        let blockPath = CGPath(roundedRect: rect, cornerWidth: blockRadius, cornerHeight: blockRadius, transform: nil)

        // Main block color
        ctx.setFillColor(CGColor(red: color.r, green: color.g, blue: color.b, alpha: 0.85))
        ctx.addPath(blockPath)
        ctx.fillPath()

        // Subtle inner highlight (top edge)
        let highlightRect = CGRect(x: rect.minX + 1, y: rect.maxY - rect.height * 0.15, width: rect.width - 2, height: rect.height * 0.15)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
        ctx.fill(highlightRect)
    }

    ctx.restoreGState()

    // Draw a subtle border around the icon shape
    ctx.addPath(iconPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.12))
    ctx.setLineWidth(s * 0.004)
    ctx.strokePath()

    // Make everything outside the rounded rect transparent
    // We need to re-render with proper masking
    image.unlockFocus()

    // Re-render with proper alpha masking
    let finalImage = NSImage(size: NSSize(width: s, height: s))
    finalImage.lockFocus()
    guard let finalCtx = NSGraphicsContext.current?.cgContext else {
        finalImage.unlockFocus()
        return nil
    }

    // Clear to transparent
    finalCtx.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // Clip to rounded rect
    finalCtx.addPath(iconPath)
    finalCtx.clip()

    // Draw the composed image
    image.draw(in: CGRect(x: 0, y: 0, width: s, height: s))

    finalImage.unlockFocus()
    return finalImage
}

func savePNG(image: NSImage, to path: String) -> Bool {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return false
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        return true
    } catch {
        print("Error writing \(path): \(error)")
        return false
    }
}

// Main execution
print("Generating DriveMosaic app icon...")
print("Output: \(iconsetPath)")

// Generate master 1024x1024
guard let masterImage = renderIcon(size: masterSize) else {
    print("ERROR: Failed to render master icon")
    exit(1)
}

// Save master and all required sizes
var success = true
for entry in iconSizes {
    let pixelSize = entry.size * entry.scale
    let filename = entry.filename
    let outputPath = "\(iconsetPath)/\(filename)"

    // Resize from master
    let resized = NSImage(size: NSSize(width: CGFloat(pixelSize), height: CGFloat(pixelSize)))
    resized.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    masterImage.draw(in: CGRect(x: 0, y: 0, width: CGFloat(pixelSize), height: CGFloat(pixelSize)))
    resized.unlockFocus()

    if savePNG(image: resized, to: outputPath) {
        print("  ✓ \(filename) (\(pixelSize)x\(pixelSize)px)")
    } else {
        print("  ✗ Failed: \(filename)")
        success = false
    }
}

if success {
    print("\nAll icons generated successfully!")
} else {
    print("\nSome icons failed to generate.")
    exit(1)
}
