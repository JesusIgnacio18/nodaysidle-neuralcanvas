#!/usr/bin/swift

// App Icon Generation Script for NeuralCanvas
// This script generates app icons at all required sizes for macOS
//
// Usage: swift generate_app_icon.swift
//
// Note: This requires running on macOS with AppKit available

import AppKit
import Foundation

// Icon sizes required for macOS
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
    (512, 2, "icon_512x512@2x.png")
]

// Create icon image
func createIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    // Background gradient
    let gradientColors = [
        NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.9, alpha: 1.0),  // Blue
        NSColor(calibratedRed: 0.4, green: 0.2, blue: 0.8, alpha: 1.0)   // Purple
    ]

    let gradient = NSGradient(colors: gradientColors)
    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    // Rounded rectangle background
    let cornerRadius = CGFloat(size) * 0.22
    let roundedPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    gradient?.draw(in: roundedPath, angle: -45)

    // Draw pencil icon (simplified)
    let centerX = CGFloat(size) / 2
    let centerY = CGFloat(size) / 2
    let iconSize = CGFloat(size) * 0.55

    // Pencil body
    NSColor.white.setFill()
    NSColor.white.setStroke()

    let pencilPath = NSBezierPath()
    let pencilWidth = iconSize * 0.15
    let pencilLength = iconSize * 0.8

    // Rotated pencil (45 degrees)
    let transform = NSAffineTransform()
    transform.translateX(by: centerX, yBy: centerY)
    transform.rotate(byDegrees: -45)

    pencilPath.move(to: NSPoint(x: -pencilLength/2, y: -pencilWidth/2))
    pencilPath.line(to: NSPoint(x: pencilLength/2 - pencilWidth, y: -pencilWidth/2))
    pencilPath.line(to: NSPoint(x: pencilLength/2, y: 0))
    pencilPath.line(to: NSPoint(x: pencilLength/2 - pencilWidth, y: pencilWidth/2))
    pencilPath.line(to: NSPoint(x: -pencilLength/2, y: pencilWidth/2))
    pencilPath.close()

    pencilPath.transform(using: transform as AffineTransform)
    pencilPath.fill()

    // Sparkle/neural dots
    let dotSize = CGFloat(size) * 0.06
    let dotColor = NSColor.white.withAlphaComponent(0.8)
    dotColor.setFill()

    let dotPositions: [(CGFloat, CGFloat)] = [
        (0.25, 0.75),
        (0.75, 0.25),
        (0.3, 0.3),
        (0.7, 0.7)
    ]

    for (xRatio, yRatio) in dotPositions {
        let dotRect = NSRect(
            x: CGFloat(size) * xRatio - dotSize/2,
            y: CGFloat(size) * yRatio - dotSize/2,
            width: dotSize,
            height: dotSize
        )
        NSBezierPath(ovalIn: dotRect).fill()
    }

    image.unlockFocus()

    return image
}

// Save image to file
func saveImage(_ image: NSImage, to path: String) -> Bool {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return false
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        return true
    } catch {
        print("Error saving \(path): \(error)")
        return false
    }
}

// Main
let outputDir = "../NeuralCanvas/Assets.xcassets/AppIcon.appiconset"

print("Generating NeuralCanvas app icons...")

for (size, scale, filename) in iconSizes {
    let actualSize = size * scale
    let icon = createIcon(size: actualSize)
    let path = "\(outputDir)/\(filename)"

    if saveImage(icon, to: path) {
        print("✓ Generated \(filename) (\(actualSize)x\(actualSize))")
    } else {
        print("✗ Failed to generate \(filename)")
    }
}

print("\nDone! Update Contents.json to reference the generated files.")
