import Cocoa
import Foundation
import UniformTypeIdentifiers

func makeIcon(size: CGFloat, path: String) {
    let w = Int(size), h = Int(size)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: size / 1024, y: size / 1024)
    let S: CGFloat = 1024

    // ---- Background gradient ----
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: S, height: S),
                        cornerWidth: S * 0.22, cornerHeight: S * 0.22, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath); ctx.clip()

    let grad = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.38, green: 0.26, blue: 0.89, alpha: 1),
            CGColor(red: 0.15, green: 0.10, blue: 0.55, alpha: 1)
        ] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(grad,
        start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0),
        options: [])
    ctx.restoreGState()

    // ---- Camera body ----
    let cx = S / 2, cy = S / 2 + 30
    let bw: CGFloat = 620, bh: CGFloat = 420
    let bl = cx - bw/2, bb = cy - bh/2
    let bodyRect = CGRect(x: bl, y: bb, width: bw, height: bh)
    let bodyPath = CGPath(roundedRect: bodyRect,
                          cornerWidth: 80, cornerHeight: 80, transform: nil)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.addPath(bodyPath); ctx.fillPath()
    ctx.restoreGState()

    // ---- Camera top bump (lens mount) ----
    let bumpW: CGFloat = 220, bumpH: CGFloat = 100
    let bumpX = cx - bumpW/2, bumpY = cy + bh/2 - 10
    let bumpRect = CGRect(x: bumpX, y: bumpY, width: bumpW, height: bumpH)
    let bumpPath = CGPath(roundedRect: bumpRect,
                          cornerWidth: 40, cornerHeight: 40, transform: nil)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.addPath(bumpPath); ctx.fillPath()
    ctx.restoreGState()

    // ---- Lens (outer ring - transparent/purple) ----
    let lensR: CGFloat = 130
    let lensPath = CGPath(ellipseIn:
        CGRect(x: cx - lensR, y: cy - lensR - 10,
               width: lensR*2, height: lensR*2),
        transform: nil)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 0.30, green: 0.20, blue: 0.75, alpha: 1))
    ctx.addPath(lensPath); ctx.fillPath()
    ctx.restoreGState()

    // ---- Lens inner ----
    let li: CGFloat = 90
    let lensInner = CGPath(ellipseIn:
        CGRect(x: cx - li, y: cy - li - 10,
               width: li*2, height: li*2),
        transform: nil)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 0.95, green: 0.93, blue: 1, alpha: 1))
    ctx.addPath(lensInner); ctx.fillPath()
    ctx.restoreGState()

    // ---- Lens center dot ----
    let lc: CGFloat = 35
    let lensCenter = CGPath(ellipseIn:
        CGRect(x: cx - lc, y: cy - lc - 10,
               width: lc*2, height: lc*2),
        transform: nil)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 0.30, green: 0.20, blue: 0.75, alpha: 1))
    ctx.addPath(lensCenter); ctx.fillPath()
    ctx.restoreGState()

    // ---- "64" text ----
    let textAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 160, weight: .bold),
        .foregroundColor: NSColor(red: 1, green: 1, blue: 1, alpha: 1)
    ]
    let t64 = NSAttributedString(string: "64", attributes: textAttrs)
    let tsize = t64.size()
    let tx = cx - tsize.width / 2
    let ty = cy - bh/2 + 40
    ctx.saveGState()
    t64.draw(at: NSPoint(x: tx, y: ty))
    ctx.restoreGState()

    // ---- Flash ----
    let flashX = bl + bw - 140, flashY = bb + bh - 90
    let flashRect = CGRect(x: flashX, y: flashY, width: 80, height: 30)
    let flashPath = CGPath(roundedRect: flashRect,
                           cornerWidth: 10, cornerHeight: 10, transform: nil)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 1, green: 0.95, blue: 0.5, alpha: 0.8))
    ctx.addPath(flashPath); ctx.fillPath()
    ctx.restoreGState()

    // ---- Save PNG ----
    guard let img = ctx.makeImage() else { return }
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

let base = "/tmp/PicBase64Icon"
try? FileManager.default.createDirectory(atPath: base + ".iconset", withIntermediateDirectories: true)

let sizes: [(CGFloat, String)] = [
    (16,"icon_16x16.png"), (32,"icon_16x16@2x.png"),
    (32,"icon_32x32.png"), (64,"icon_32x32@2x.png"),
    (128,"icon_128x128.png"), (256,"icon_128x128@2x.png"),
    (256,"icon_256x256.png"), (512,"icon_256x256@2x.png"),
    (512,"icon_512x512.png"), (1024,"icon_512x512@2x.png"),
]
for (sz, name) in sizes {
    makeIcon(size: sz, path: "\(base).iconset/\(name)")
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", "-o", "/tmp/PicBase64.icns", base + ".iconset"]
try task.run(); task.waitUntilExit()
print("icns:", FileManager.default.fileExists(atPath: "/tmp/PicBase64.icns") ? "OK" : "FAIL")
