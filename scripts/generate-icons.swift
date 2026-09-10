import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let mark = NSImage(contentsOf: root.appendingPathComponent("Sources/Panda/Resources/PandaMark.png"))!
func render(size: Int, draw: () -> Void) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
func appIcon(_ size: Int) -> Data {
    render(size: size) {
        let n = CGFloat(size)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: CGRect(x: n * 0.06, y: n * 0.06, width: n * 0.88, height: n * 0.88), xRadius: n * 0.20, yRadius: n * 0.20).fill()
        mark.draw(in: CGRect(x: n * 0.18, y: n * 0.18, width: n * 0.64, height: n * 0.64))
    }
}
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try appIcon(points * scale).write(to: output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
try appIcon(1024).write(to: root.appendingPathComponent("docs/brand/panda-app-icon.png"))
