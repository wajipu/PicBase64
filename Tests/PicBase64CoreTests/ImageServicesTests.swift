import AppKit
@testable import PicBase64Core
import XCTest

final class ImageServicesTests: XCTestCase {
    func testDecodeBase64DataAcceptsRawDataURLMarkdownAndQuotes() throws {
        let png = try fixturePNGData()
        let base64 = png.base64EncodedString()

        XCTAssertEqual(try ImageServices.decodeBase64Data(base64), png)
        XCTAssertEqual(try ImageServices.decodeBase64Data("data:image/png;base64,\(base64)"), png)
        XCTAssertEqual(try ImageServices.decodeBase64Data("![sample](data:image/png;base64,\(base64))"), png)
        XCTAssertEqual(try ImageServices.decodeBase64Data("\"\n\(base64)\n\""), png)
    }

    func testEncodeFormatsMatchExistingAppOutput() throws {
        let png = try fixturePNGData()
        let base64 = png.base64EncodedString()

        XCTAssertEqual(
            ImageServices.encode(data: png, label: "test", format: .raw).output,
            base64
        )
        XCTAssertEqual(
            ImageServices.encode(data: png, label: "test", format: .dataURL).output,
            "data:image/png;base64,\(base64)"
        )
        XCTAssertEqual(
            ImageServices.encode(data: png, label: "test", format: .markdown).output,
            "![test](data:image/png;base64,\(base64))"
        )

        let jsonOutput = ImageServices.encode(data: png, label: "test", format: .json).output
        let jsonData = try XCTUnwrap(jsonOutput.data(using: .utf8))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        XCTAssertEqual(object["type"] as? String, "image/png")
        XCTAssertEqual(object["data"] as? String, base64)
        XCTAssertEqual(object["size"] as? Int, png.count)
    }

    func testWritePNGFileCreatesImageFile() throws {
        let png = try fixturePNGData()
        let outputPath = NSTemporaryDirectory() + "PicBase64CoreTests_\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        let writtenPath = try ImageServices.writePNGFile(data: png, outputPath: outputPath)
        XCTAssertEqual(writtenPath, URL(fileURLWithPath: outputPath).standardizedFileURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: writtenPath))
        XCTAssertNotNil(NSImage(contentsOfFile: writtenPath))
    }

    private func fixturePNGData() throws -> Data {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill()
        image.unlockFocus()
        return try ImageServices.pngData(from: image)
    }
}
