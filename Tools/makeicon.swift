#!/usr/bin/env swift
import AppKit

// Gera o AppIcon.icns: quadrado arredondado grafite com a seta dupla branca.
// Roda no build; nao existe arte binaria versionada no repositorio.

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return image }
    ctx.setShouldAntialias(true)

    let inset = size * 0.055
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.2237 // squircle aproximado do macOS
    let body = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.24, green: 0.25, blue: 0.29, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.12, alpha: 1),
    ])
    gradient?.draw(in: body, angle: -90)

    // borda de luz no topo
    NSColor(white: 1, alpha: 0.16).setStroke()
    body.lineWidth = size * 0.006
    body.stroke()

    // faixa clara representando a barra de menus
    let barHeight = rect.height * 0.16
    let bar = NSRect(x: rect.minX, y: rect.maxY - barHeight, width: rect.width, height: barHeight)
    NSGraphicsContext.saveGraphicsState()
    body.addClip()
    NSColor(white: 1, alpha: 0.10).setFill()
    bar.fill()
    NSGraphicsContext.restoreGraphicsState()

    // seta dupla
    let center = NSPoint(x: rect.midX + rect.width * 0.03, y: rect.midY - rect.height * 0.04)
    let arm = rect.width * 0.17
    let lineWidth = rect.width * 0.085
    NSColor.white.setStroke()
    for offset in [-arm * 0.75, arm * 0.55] {
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: NSPoint(x: center.x + offset + arm * 0.5, y: center.y + arm))
        path.line(to: NSPoint(x: center.x + offset - arm * 0.5, y: center.y))
        path.line(to: NSPoint(x: center.x + offset + arm * 0.5, y: center.y - arm))
        path.stroke()
    }

    image.unlockFocus()
    return image
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

let variants: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, size) in variants {
    let image = drawIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try? png.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
}
print("iconset em \(out)")
