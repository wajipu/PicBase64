import Cocoa
import Foundation
import UniformTypeIdentifiers

func makeFlatIcon(size: CGFloat, path: String) {
    let w = Int(size), h = Int(size)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: size / 1024, y: size / 1024)
    let S: CGFloat = 1024

    // 1. 扁平化渐变背景（轻微渐变增加质感）
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: S, height: S),
                        cornerWidth: S * 0.22, cornerHeight: S * 0.22, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath); ctx.clip()

    let grad = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 0.18, green: 0.78, blue: 0.96, alpha: 1),  // #2EC7F5 顶部亮
            CGColor(red: 0.10, green: 0.56, blue: 0.95, alpha: 1)   // #1A8FF2 底部深
        ] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(grad,
        start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0),
        options: [])
    ctx.restoreGState()

    // 2. 图片图标（扁平白色矩形 + 山峰 + 太阳）
    let rectY: CGFloat = S * 0.32
    let rectH: CGFloat = S * 0.48
    let rectW: CGFloat = S * 0.56
    let rectX = (S - rectW) / 2
    let imageRect = CGPath(roundedRect: CGRect(x: rectX, y: rectY, width: rectW, height: rectH),
                          cornerWidth: 48, cornerHeight: 48, transform: nil)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.addPath(imageRect); ctx.fillPath()

    // 太阳（右上角）
    let sunR: CGFloat = 55
    ctx.setFillColor(CGColor(red: 1.0, green: 0.78, blue: 0.22, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: rectX + rectW - sunR - 70,
                               y: rectY + rectH - sunR - 85,
                               width: sunR*2, height: sunR*2))

    // 山峰（青色山峰）
    let mountainPath = CGMutablePath()
    let mountainY = rectY + rectH
    mountainPath.move(to: CGPoint(x: rectX + 60, y: mountainY))
    mountainPath.addLine(to: CGPoint(x: rectX + rectW * 0.35, y: mountainY - rectH * 0.55))
    mountainPath.addLine(to: CGPoint(x: rectX + rectW * 0.55, y: mountainY - rectH * 0.35))
    mountainPath.addLine(to: CGPoint(x: rectX + rectW * 0.80, y: mountainY - rectH * 0.70))
    mountainPath.addLine(to: CGPoint(x: rectX + rectW - 60, y: mountainY))
    mountainPath.closeSubpath()
    ctx.setFillColor(CGColor(red: 0.18, green: 0.78, blue: 1.0, alpha: 1))
    ctx.addPath(mountainPath); ctx.fillPath()

    // 3. "64" 文字（在图片下方，扁平白色粗体）
    let textAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 200, weight: .black),
        .foregroundColor: NSColor(red: 1, green: 1, blue: 1, alpha: 1)
    ]
    let t64 = NSAttributedString(string: "64", attributes: textAttrs)
    let tsize = t64.size()
    t64.draw(at: NSPoint(x: (S - tsize.width)/2, y: S * 0.08))
    ctx.restoreGState()

    // 保存图片
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
    makeFlatIcon(size: sz, path: "\(base).iconset/\(name)")
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", "-o", "/tmp/PicBase64.icns", base + ".iconset"]
try task.run(); task.waitUntilExit()
print("icns:", FileManager.default.fileExists(atPath: "/tmp/PicBase64.icns") ? "OK" : "FAIL")

// 生成一个预览 PNG
makeFlatIcon(size: 512, path: "/tmp/PicBase64_preview.png")
