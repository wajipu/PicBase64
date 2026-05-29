import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum OutputFormat: String, CaseIterable, Sendable {
    case raw = "raw"
    case dataURL = "data"
    case markdown = "md"
    case json = "json"
}

public enum ScreenshotMode: String, CaseIterable, Sendable {
    case region
    case window
    case full
}

public enum PicBase64Error: LocalizedError {
    case noClipboardImage
    case imageEncodingFailed
    case invalidBase64
    case invalidImageData
    case fileNotFound(String)
    case screenshotFailed(Int32)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noClipboardImage:
            return "No image was found in the clipboard."
        case .imageEncodingFailed:
            return "The image could not be encoded as PNG."
        case .invalidBase64:
            return "The input is not valid Base64 image data."
        case .invalidImageData:
            return "The data could not be decoded as an image."
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .screenshotFailed(let status):
            return "Screenshot failed with status \(status)."
        case .writeFailed(let path):
            return "Could not write file: \(path)"
        }
    }
}

public struct ImageDetails: Codable, Hashable, Sendable {
    public let mimeType: String
    public let byteCount: Int
    public let base64Length: Int
    public let width: Int
    public let height: Int

    public init(mimeType: String, byteCount: Int, base64Length: Int, width: Int, height: Int) {
        self.mimeType = mimeType
        self.byteCount = byteCount
        self.base64Length = base64Length
        self.width = width
        self.height = height
    }
}

public struct EncodedImage: Codable, Hashable, Sendable {
    public let format: String
    public let output: String
    public let base64: String
    public let details: ImageDetails
    public let savedPath: String?

    public init(
        format: String,
        output: String,
        base64: String,
        details: ImageDetails,
        savedPath: String? = nil
    ) {
        self.format = format
        self.output = output
        self.base64 = base64
        self.details = details
        self.savedPath = savedPath
    }
}

public enum ImageServices {
    public static func pngData(from image: NSImage) throws -> Data {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            throw PicBase64Error.imageEncodingFailed
        }
        return pngData
    }

    public static func normalizedPNGData(from data: Data) throws -> Data {
        if let rep = NSBitmapImageRep(data: data),
           let pngData = rep.representation(using: .png, properties: [:]) {
            return pngData
        }

        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
           let pngData = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) {
            return pngData
        }

        guard let image = NSImage(data: data) else {
            throw PicBase64Error.invalidImageData
        }
        return try pngData(from: image)
    }

    public static func imageSize(from data: Data) throws -> NSSize {
        guard let image = NSImage(data: data) else {
            throw PicBase64Error.invalidImageData
        }
        return image.size
    }

    public static func encode(
        data: Data,
        mimeType: String = "image/png",
        label: String,
        format: OutputFormat,
        savedPath: String? = nil
    ) -> EncodedImage {
        let base64 = data.base64EncodedString()
        let output: String

        switch format {
        case .raw:
            output = base64
        case .dataURL:
            output = "data:\(mimeType);base64,\(base64)"
        case .markdown:
            output = "![\(label)](data:\(mimeType);base64,\(base64))"
        case .json:
            let json: [String: Any] = [
                "type": mimeType,
                "data": base64,
                "size": data.count
            ]
            if let jsonData = try? JSONSerialization.data(
                withJSONObject: json,
                options: [.prettyPrinted, .sortedKeys]
            ), let jsonString = String(data: jsonData, encoding: .utf8) {
                output = jsonString
            } else {
                output = base64
            }
        }

        let size = (try? imageSize(from: data)) ?? .zero
        let details = ImageDetails(
            mimeType: mimeType,
            byteCount: data.count,
            base64Length: base64.count,
            width: Int(size.width),
            height: Int(size.height)
        )
        return EncodedImage(
            format: format.rawValue,
            output: output,
            base64: base64,
            details: details,
            savedPath: savedPath
        )
    }

    public static func decodeBase64Data(_ input: String) throws -> Data {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if value.hasPrefix("!["),
           let start = value.range(of: "base64,"),
           let end = value.range(of: ")", options: .backwards) {
            value = String(value[start.upperBound..<end.lowerBound])
        }

        if value.hasPrefix("data:"), let comma = value.range(of: ",") {
            value = String(value[comma.upperBound...])
        }

        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
            (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast())
        }

        value = value.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)

        guard let data = Data(base64Encoded: value, options: .ignoreUnknownCharacters) else {
            throw PicBase64Error.invalidBase64
        }
        return data
    }

    public static func decodeBase64ImageData(_ input: String) throws -> Data {
        let data = try decodeBase64Data(input)
        guard NSImage(data: data) != nil else {
            throw PicBase64Error.invalidImageData
        }
        return data
    }

    public static func readClipboardPNGData() throws -> Data {
        let pasteboard = NSPasteboard.general
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            return try pngData(from: image)
        }

        if let pngData = pasteboard.data(forType: .png),
           NSImage(data: pngData) != nil {
            return pngData
        }

        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData) {
            return try pngData(from: image)
        }

        throw PicBase64Error.noClipboardImage
    }

    public static func copyStringToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    public static func copyPNGToClipboard(_ data: Data) throws {
        guard let image = NSImage(data: data) else {
            throw PicBase64Error.invalidImageData
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    public static func screenshot(mode: ScreenshotMode) throws -> Data {
        let tmpFile = NSTemporaryDirectory() + "PicBase64_\(UUID().uuidString).png"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")

        switch mode {
        case .region:
            task.arguments = ["-i", "-x", tmpFile]
        case .window:
            task.arguments = ["-iW", "-x", tmpFile]
        case .full:
            task.arguments = ["-x", tmpFile]
        }

        try task.run()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else {
            throw PicBase64Error.screenshotFailed(task.terminationStatus)
        }
        guard FileManager.default.fileExists(atPath: tmpFile) else {
            throw PicBase64Error.screenshotFailed(task.terminationStatus)
        }
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }
        return try Data(contentsOf: URL(fileURLWithPath: tmpFile))
    }

    public static func imageFileData(path: String) throws -> (data: Data, mimeType: String) {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PicBase64Error.fileNotFound(path)
        }
        let data = try Data(contentsOf: url)
        guard NSImage(data: data) != nil else {
            throw PicBase64Error.invalidImageData
        }
        return (data, mimeType(for: url))
    }

    public static func writePNGFile(data: Data, outputPath: String?) throws -> String {
        let pngData = isPNGData(data) ? data : try normalizedPNGData(from: data)
        let destination: URL
        if let outputPath, !outputPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            destination = URL(fileURLWithPath: outputPath).standardizedFileURL
        } else {
            let filename = "PicBase64_\(Int(Date().timeIntervalSince1970)).png"
            destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        }

        do {
            let folder = destination.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try pngData.write(to: destination, options: .atomic)
        } catch {
            throw PicBase64Error.writeFailed(destination.path)
        }
        return destination.path
    }

    public static func isPNGData(_ data: Data) -> Bool {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        return data.starts(with: signature)
    }

    public static func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension),
           let mimeType = type.preferredMIMEType,
           mimeType.hasPrefix("image/") {
            return mimeType
        }
        return "image/png"
    }
}
