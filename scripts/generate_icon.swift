#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let size: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("ctx") }

// Match JournalToObsidian: subtle dark gradient
let bg1 = CGColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
let bg2 = CGColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
let grad = CGGradient(colorsSpace: cs, colors: [bg1, bg2] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    grad,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: 0, y: 0),
    options: []
)

let center = CGPoint(x: size / 2, y: size / 2)
let radius: CGFloat = size * 0.30
let stroke: CGFloat = size * 0.045

let white = CGColor(red: 1, green: 1, blue: 1, alpha: 0.95)

// Outer ring (thin, white)
ctx.setStrokeColor(white)
ctx.setLineWidth(stroke)
ctx.setLineCap(.round)
ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()

// Play triangle, centered, slight optical right shift
let triHeight: CGFloat = radius * 0.95
let triWidth: CGFloat = triHeight * 0.866 // equilateral-ish
let cx = center.x + triWidth * 0.10  // optical centering
let cy = center.y
let path = CGMutablePath()
path.move(to: CGPoint(x: cx - triWidth / 2, y: cy + triHeight / 2))
path.addLine(to: CGPoint(x: cx - triWidth / 2, y: cy - triHeight / 2))
path.addLine(to: CGPoint(x: cx + triWidth / 2, y: cy))
path.closeSubpath()

ctx.setFillColor(white)
ctx.addPath(path)
ctx.fillPath()

guard let cgImage = ctx.makeImage() else { fatalError("image") }
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("png") }

let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
try data.write(to: outURL)
print("wrote \(outURL.path)")
