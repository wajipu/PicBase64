import AppKit

class IconManager {
    static let shared = IconManager()
    private var cache: [String: NSImage] = [:]
    
    private init() {}
    
    func icon(_ name: String, size: CGFloat = 16) -> NSImage? {
        let cacheKey = "\(name)-\(size)"
        if let cached = cache[cacheKey] {
            return cached
        }
        
        guard let svgData = loadSVG(name: name),
              let image = svgDataToNSImage(svgData, size: size) else {
            return nil
        }
        
        image.isTemplate = true
        cache[cacheKey] = image
        return image
    }
    
    private func loadSVG(name: String) -> Data? {
        let paths = [
            Bundle.main.path(forResource: name, ofType: "svg", inDirectory: "icons"),
            Bundle.main.resourcePath?.appending("/icons/\(name).svg"),
            "/Users/wajipu/Downloads/PicBase64_4.0/PicBase64.app/Contents/Resources/icons/\(name).svg"
        ]
        
        for path in paths {
            if let path = path, FileManager.default.fileExists(atPath: path) {
                return FileManager.default.contents(atPath: path)
            }
        }
        return nil
    }
    
    private func svgDataToNSImage(_ data: Data, size: CGFloat) -> NSImage? {
        guard let svgString = String(data: data, encoding: .utf8) else { return nil }
        
        // 修改 SVG 使用黑色
        let modifiedSVG = svgString
            .replacingOccurrences(of: "#000000", with: "#000000")
            .replacingOccurrences(of: "currentColor", with: "#000000")
        
        guard let modifiedData = modifiedSVG.data(using: .utf8),
              let baseImage = NSImage(data: modifiedData) else {
            return nil
        }
        
        // 缩放到目标大小
        let finalImage = NSImage(size: NSSize(width: size, height: size))
        finalImage.lockFocus()
        baseImage.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                      from: NSRect.zero,
                      operation: .sourceOver,
                      fraction: 1.0)
        finalImage.unlockFocus()
        
        return finalImage
    }
}
