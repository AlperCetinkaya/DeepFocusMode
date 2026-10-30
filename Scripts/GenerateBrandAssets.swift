// Run from the project root: swift Scripts/GenerateBrandAssets.swift
// Native vector masters and deterministic size exports; no external packages.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let brand = root.appendingPathComponent("Assets/Brand")
let catalog = root.appendingPathComponent("DeepFocusMode/Resources/Assets.xcassets")
let manager = FileManager.default
guard let master = NSImage(contentsOf: brand.appendingPathComponent("AppIconMaster.png")) else {
    fatalError("Missing Assets/Brand/AppIconMaster.png")
}

func writePNG(to url: URL, size: NSSize, draw: () -> Void) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width),
                                  pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4,
                                  hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

func writeJSON(_ value: [String: Any], to url: URL) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url)
}

// Top-left coordinate system, shared by PDF, SVG and preview output.
func drawMark(active: Bool, color: NSColor) {
    color.setStroke()
    color.setFill()
    let border = NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: 28, height: 28), xRadius: 7, yRadius: 7)
    border.lineWidth = 1.7
    border.stroke()
    NSGraphicsContext.saveGraphicsState()
    border.addClip()
    let moon = NSBezierPath(ovalIn: NSRect(x: 10, y: 7, width: 12, height: 12))
    if active { moon.fill() } else { moon.lineWidth = 1.6; moon.stroke() }

    // Keep separation between the moon and dunes at actual 18pt menu-bar size.
    let back = NSBezierPath()
    back.move(to: NSPoint(x: 2, y: 19))
    back.curve(to: NSPoint(x: 20, y: 20), controlPoint1: NSPoint(x: 8, y: 13), controlPoint2: NSPoint(x: 12, y: 16))
    back.lineWidth = 1.6
    back.lineCapStyle = .round
    back.stroke()

    let front = NSBezierPath()
    front.move(to: NSPoint(x: 2, y: 25))
    front.curve(to: NSPoint(x: 30, y: 20), controlPoint1: NSPoint(x: 14, y: 24), controlPoint2: NSPoint(x: 23, y: 13))
    if active {
        front.line(to: NSPoint(x: 30, y: 31))
        front.line(to: NSPoint(x: 2, y: 31))
        front.close()
        front.fill()
    } else {
        front.lineWidth = 1.6
        front.lineCapStyle = .round
        front.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
}

final class MarkView: NSView {
    let active: Bool
    init(active: Bool) { self.active = active; super.init(frame: NSRect(x: 0, y: 0, width: 16, height: 16)) }
    required init?(coder: NSCoder) { fatalError("Not used") }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.scale(by: 0.5)
        transform.concat()
        drawMark(active: active, color: .black)
        NSGraphicsContext.restoreGraphicsState()
    }
}

let info: [String: Any] = ["author": "xcode", "version": 1]
try writeJSON(["info": info], to: catalog.appendingPathComponent("Contents.json"))
var appImages: [[String: Any]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let filename = "AppIcon-\(points)@\(scale)x.png"
        let size = NSSize(width: pixels, height: pixels)
        try writePNG(to: catalog.appendingPathComponent("AppIcon.appiconset/\(filename)"), size: size) {
            master.draw(in: NSRect(origin: .zero, size: size))
        }
        appImages.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": filename])
    }
}
try writeJSON(["images": appImages, "info": info], to: catalog.appendingPathComponent("AppIcon.appiconset/Contents.json"))

for scale in [1, 2] {
    let size = NSSize(width: 128 * scale, height: 128 * scale)
    try writePNG(to: catalog.appendingPathComponent("BrandIcon.imageset/BrandIcon@\(scale)x.png"), size: size) {
        master.draw(in: NSRect(origin: .zero, size: size))
    }
}
try writeJSON(["images": (1...2).map { ["idiom": "mac", "scale": "\($0)x", "filename": "BrandIcon@\($0)x.png"] },
               "info": info], to: catalog.appendingPathComponent("BrandIcon.imageset/Contents.json"))

for active in [false, true] {
    let name = active ? "MenuBarActive" : "MenuBarInactive"
    let view = MarkView(active: active)
    try view.dataWithPDF(inside: view.bounds).write(to: catalog.appendingPathComponent("\(name).imageset/\(name).pdf"))
    try writeJSON(["images": [["idiom": "universal", "filename": "\(name).pdf"]], "info": info,
                   "properties": ["preserves-vector-representation": true, "template-rendering-intent": "template"]],
                  to: catalog.appendingPathComponent("\(name).imageset/Contents.json"))
    let moon = active ? #"<circle cx="16" cy="13" r="6" fill="currentColor"/>"# : #"<circle cx="16" cy="13" r="6" fill="none" stroke="currentColor" stroke-width="1.6"/>"#
    let front = active ? #"<path d="M2 25 C14 24 23 13 30 20 L30 31 L2 31 Z" fill="currentColor"/>"# : #"<path d="M2 25 C14 24 23 13 30 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>"#
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
    <defs><clipPath id="body"><rect x="2" y="2" width="28" height="28" rx="7"/></clipPath></defs>
    <rect x="2" y="2" width="28" height="28" rx="7" fill="none" stroke="currentColor" stroke-width="1.7"/>
    <g clip-path="url(#body)">\(moon)<path d="M2 19 C8 13 12 16 20 20" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>\(front)</g>
    </svg>
    """
    try svg.write(to: brand.appendingPathComponent("\(name).svg"), atomically: true, encoding: .utf8)
    try writePNG(to: brand.appendingPathComponent("\(name)-preview.png"), size: NSSize(width: 192, height: 192)) {
        NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 192, height: 192).fill()
        let transform = NSAffineTransform()
        transform.translateX(by: 0, yBy: 192)
        transform.scaleX(by: 6, yBy: -6)
        transform.concat()
        drawMark(active: active, color: .black)
    }
}

// A review sheet includes actual 16pt menu-bar size and larger geometry previews on both appearances.
let previewSize = NSSize(width: 1060, height: 540)
try writePNG(to: brand.appendingPathComponent("BrandPreview.png"), size: previewSize) {
    NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
    NSRect(origin: .zero, size: previewSize).fill()
    master.draw(in: NSRect(x: 28, y: 90, width: 340, height: 340))
    func text(_ text: String, at point: NSPoint, size: CGFloat, color: NSColor) {
        (text as NSString).draw(at: point, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium),
                                                           .foregroundColor: color])
    }
    text("Deep Focus Mode", at: NSPoint(x: 55, y: 46), size: 23, color: .black)
    for (index, dark) in [false, true].enumerated() {
        let y = index == 0 ? CGFloat(300) : CGFloat(54)
        let rect = NSRect(x: 400, y: y, width: 620, height: 212)
        let background = dark ? NSColor(calibratedWhite: 0.10, alpha: 1) : .white
        let ink: NSColor = dark ? .white : .black
        background.setFill(); NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18).fill()
        text(dark ? "Dark appearance" : "Light appearance", at: NSPoint(x: 425, y: y + 170), size: 17, color: ink)
        for (offset, active) in [false, true].enumerated() {
            let x = CGFloat(460 + offset * 270)
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: x, yBy: y + 145)
            transform.scaleX(by: 2.5, yBy: -2.5)
            transform.concat()
            drawMark(active: active, color: ink)
            NSGraphicsContext.restoreGraphicsState()
            NSGraphicsContext.saveGraphicsState()
            let actual = NSAffineTransform()
            actual.translateX(by: x + 104, yBy: y + 116)
            actual.scaleX(by: 16.0 / 32, yBy: -16.0 / 32)
            actual.concat()
            drawMark(active: active, color: ink)
            NSGraphicsContext.restoreGraphicsState()
            text(active ? "Focus on · 16 pt" : "Focus off · 16 pt", at: NSPoint(x: x, y: y + 34), size: 14, color: ink)
        }
    }
}
print("Exported AppIcon sizes, in-app brand image, vector templates and BrandPreview.png")
