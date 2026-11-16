// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import Foundation

// Draws the Dă-i master icon: a white double chevron on an orange-to-pink tile.
guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift DrawIcon.swift <output.png>\n", stderr)
    exit(2)
}

let size: CGFloat = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Could not create icon bitmap\n", stderr)
    exit(1)
}
NSGraphicsContext.current = graphics
let context = graphics.cgContext

func gray(_ white: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: white, green: white, blue: white, alpha: alpha)
}
let orange = CGColor(red: 1.0, green: 0.62, blue: 0.10, alpha: 1)
let pink = CGColor(red: 1.0, green: 0.18, blue: 0.42, alpha: 1)

// Tile, on the standard macOS icon grid (824 pt body inside a 1024 pt canvas).
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: gray(0, 0.35))
context.addPath(tilePath)
context.setFillColor(pink)
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(tilePath)
context.clip()
let space = CGColorSpaceCreateDeviceRGB()
let fill = CGGradient(colorsSpace: space, colors: [orange, pink] as CFArray, locations: [0, 1])!
context.drawLinearGradient(
    fill, start: CGPoint(x: tile.minX, y: tile.maxY), end: CGPoint(x: tile.maxX, y: tile.minY), options: [])
let sheen = CGGradient(colorsSpace: space, colors: [gray(1, 0.22), gray(1, 0)] as CFArray, locations: [0, 1])!
context.drawRadialGradient(
    sheen, startCenter: CGPoint(x: 512, y: tile.maxY), startRadius: 0,
    endCenter: CGPoint(x: 512, y: tile.maxY), endRadius: 620, options: [])
context.restoreGState()

// Lit top edge.
context.saveGState()
context.addPath(tilePath)
context.clip()
context.addPath(CGPath(
    roundedRect: tile.insetBy(dx: 3, dy: 3), cornerWidth: 183, cornerHeight: 183, transform: nil))
context.setLineWidth(6)
context.replacePathWithStrokedPath()
context.clip()
let edge = CGGradient(colorsSpace: space, colors: [gray(1, 0.45), gray(1, 0)] as CFArray, locations: [0, 1])!
context.drawLinearGradient(
    edge, start: CGPoint(x: 512, y: tile.maxY), end: CGPoint(x: 512, y: 512), options: [])
context.restoreGState()

func chevron(centerX: CGFloat, color: CGColor, shadow: Bool) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: centerX - 95, y: 512 + 190))
    path.addLine(to: CGPoint(x: centerX + 95, y: 512))
    path.addLine(to: CGPoint(x: centerX - 95, y: 512 - 190))
    context.saveGState()
    if shadow { context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(red: 0.5, green: 0, blue: 0.15, alpha: 0.45)) }
    context.addPath(path)
    context.setStrokeColor(color)
    context.setLineWidth(96)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()
    context.restoreGState()
}

chevron(centerX: 402, color: gray(1, 0.45), shadow: false)
chevron(centerX: 622, color: gray(1), shadow: true)

graphics.flushGraphics()
guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
