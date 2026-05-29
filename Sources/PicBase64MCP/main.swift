import AppKit
import Foundation
import MCP
import PicBase64Core

@main
struct PicBase64MCPServer {
    static func main() async throws {
        let server = Server(
            name: "picbase64",
            version: "0.1.0",
            title: "PicBase64 Agent Bridge",
            instructions: "Local-only image, screenshot, clipboard, and Base64 tools for macOS.",
            capabilities: .init(tools: .init())
        )

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: PicBase64Tools.tools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            await PicBase64Tools.call(name: params.name, arguments: params.arguments ?? [:])
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}

enum PicBase64Tools {
    static let tools: [Tool] = [
        Tool(
            name: "clipboard_image_to_base64",
            title: "Clipboard Image to Base64",
            description: "Read the current macOS clipboard image and return Base64, a data URL, Markdown, or JSON.",
            inputSchema: objectSchema(
                properties: [
                    "format": enumSchema(["data", "raw", "md", "json"], description: "Output format. Defaults to data."),
                    "copy_to_clipboard": boolSchema("When true, copy the formatted output back to the clipboard.")
                ]
            ),
            annotations: .init(readOnlyHint: false, openWorldHint: false)
        ),
        Tool(
            name: "capture_screenshot",
            title: "Capture Screenshot",
            description: "Capture a macOS region, window, or full-screen screenshot and return the image as Base64 output.",
            inputSchema: objectSchema(
                properties: [
                    "mode": enumSchema(["region", "window", "full"], description: "Capture mode. Defaults to region."),
                    "format": enumSchema(["data", "raw", "md", "json"], description: "Output format. Defaults to data."),
                    "save_path": stringSchema("Optional PNG path to save the screenshot."),
                    "copy_to_clipboard": boolSchema("When true, copy the formatted output back to the clipboard.")
                ]
            ),
            annotations: .init(readOnlyHint: false, openWorldHint: false)
        ),
        Tool(
            name: "image_file_to_base64",
            title: "Image File to Base64",
            description: "Read a local image file and return Base64, a data URL, Markdown, or JSON.",
            inputSchema: objectSchema(
                properties: [
                    "path": stringSchema("Absolute or relative path to the local image file."),
                    "format": enumSchema(["data", "raw", "md", "json"], description: "Output format. Defaults to data."),
                    "copy_to_clipboard": boolSchema("When true, copy the formatted output back to the clipboard.")
                ],
                required: ["path"]
            ),
            annotations: .init(readOnlyHint: true, openWorldHint: false)
        ),
        Tool(
            name: "base64_to_image_file",
            title: "Base64 to Image File",
            description: "Decode Base64, data URL, or Markdown image data and write a local PNG file.",
            inputSchema: objectSchema(
                properties: [
                    "input": stringSchema("Base64 image data, data URL, or Markdown image data."),
                    "output_path": stringSchema("Optional PNG destination path. Defaults to a temporary file."),
                    "copy_image_to_clipboard": boolSchema("When true, copy the decoded PNG image to the clipboard.")
                ],
                required: ["input"]
            ),
            annotations: .init(readOnlyHint: false, openWorldHint: false)
        )
    ]

    static func call(name: String, arguments: [String: MCP.Value]) async -> CallTool.Result {
        do {
            switch name {
            case "clipboard_image_to_base64":
                return try encodedImageResult(
                    data: ImageServices.readClipboardPNGData(),
                    mimeType: "image/png",
                    label: "clipboard",
                    format: arguments.outputFormat(default: .dataURL),
                    copyToClipboard: arguments.bool("copy_to_clipboard") ?? false
                )

            case "capture_screenshot":
                let mode = try arguments.screenshotMode(default: .region)
                let data = try ImageServices.screenshot(mode: mode)
                let savedPath: String?
                if let path = arguments.string("save_path"), !path.isEmpty {
                    savedPath = try ImageServices.writePNGFile(data: data, outputPath: path)
                } else {
                    savedPath = nil
                }
                return try encodedImageResult(
                    data: data,
                    mimeType: "image/png",
                    label: "screenshot",
                    format: arguments.outputFormat(default: .dataURL),
                    savedPath: savedPath,
                    copyToClipboard: arguments.bool("copy_to_clipboard") ?? false
                )

            case "image_file_to_base64":
                guard let path = arguments.string("path"), !path.isEmpty else {
                    throw ToolArgumentError.missing("path")
                }
                let file = try ImageServices.imageFileData(path: path)
                let label = URL(fileURLWithPath: path).lastPathComponent
                return try encodedImageResult(
                    data: file.data,
                    mimeType: file.mimeType,
                    label: label,
                    format: arguments.outputFormat(default: .dataURL),
                    copyToClipboard: arguments.bool("copy_to_clipboard") ?? false
                )

            case "base64_to_image_file":
                let inputData = try arguments.imageInputData("input")
                let path = try ImageServices.writePNGFile(
                    data: inputData,
                    outputPath: arguments.string("output_path")
                )
                let pngData = try Data(contentsOf: URL(fileURLWithPath: path))
                if arguments.bool("copy_image_to_clipboard") ?? false {
                    try ImageServices.copyPNGToClipboard(pngData)
                }
                let size = try ImageServices.imageSize(from: pngData)
                return try jsonResult(DecodedImagePayload(
                    ok: true,
                    path: path,
                    mimeType: "image/png",
                    byteCount: pngData.count,
                    width: Int(size.width),
                    height: Int(size.height)
                ))

            default:
                return errorResult("Unknown tool: \(name)")
            }
        } catch {
            return errorResult(error.localizedDescription)
        }
    }

    static func encodedImageResult(
        data: Data,
        mimeType: String,
        label: String,
        format: OutputFormat,
        savedPath: String? = nil,
        copyToClipboard: Bool
    ) throws -> CallTool.Result {
        let encoded = ImageServices.encode(
            data: data,
            mimeType: mimeType,
            label: label,
            format: format,
            savedPath: savedPath
        )
        if copyToClipboard {
            ImageServices.copyStringToClipboard(encoded.output)
        }

        return try jsonResult(EncodedImagePayload(
            ok: true,
            format: encoded.format,
            output: encoded.output,
            base64: encoded.base64,
            mimeType: encoded.details.mimeType,
            byteCount: encoded.details.byteCount,
            base64Length: encoded.details.base64Length,
            width: encoded.details.width,
            height: encoded.details.height,
            savedPath: encoded.savedPath
        ))
    }

    static func jsonResult<T: Codable>(_ payload: T) throws -> CallTool.Result {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        let text = String(decoding: data, as: UTF8.self)
        let structured = (try? MCP.Value(payload)) ?? .null

        return try CallTool.Result(
            content: [.text(text: text, annotations: nil, _meta: nil)],
            structuredContent: structured,
            isError: false
        )
    }

    static func errorResult(_ message: String) -> CallTool.Result {
        CallTool.Result(
            content: [.text(text: message, annotations: nil, _meta: nil)],
            isError: true
        )
    }

    static func objectSchema(properties: [String: MCP.Value], required: [String] = []) -> MCP.Value {
        var schema: [String: MCP.Value] = [
            "type": "object",
            "properties": .object(properties)
        ]
        if !required.isEmpty {
            schema["required"] = .array(required.map { .string($0) })
        }
        return .object(schema)
    }

    static func enumSchema(_ values: [String], description: String) -> MCP.Value {
        .object([
            "type": "string",
            "description": .string(description),
            "enum": .array(values.map { .string($0) })
        ])
    }

    static func stringSchema(_ description: String) -> MCP.Value {
        .object([
            "type": "string",
            "description": .string(description)
        ])
    }

    static func boolSchema(_ description: String) -> MCP.Value {
        .object([
            "type": "boolean",
            "description": .string(description)
        ])
    }
}

struct EncodedImagePayload: Codable, Sendable {
    let ok: Bool
    let format: String
    let output: String
    let base64: String
    let mimeType: String
    let byteCount: Int
    let base64Length: Int
    let width: Int
    let height: Int
    let savedPath: String?
}

struct DecodedImagePayload: Codable, Sendable {
    let ok: Bool
    let path: String
    let mimeType: String
    let byteCount: Int
    let width: Int
    let height: Int
}

enum ToolArgumentError: LocalizedError {
    case missing(String)
    case invalid(String, String)

    var errorDescription: String? {
        switch self {
        case .missing(let name):
            return "Missing required argument: \(name)"
        case .invalid(let name, let value):
            return "Invalid argument \(name): \(value)"
        }
    }
}

extension Dictionary where Key == String, Value == MCP.Value {
    func string(_ key: String) -> String? {
        self[key]?.stringValue
    }

    func bool(_ key: String) -> Bool? {
        self[key]?.boolValue
    }

    func outputFormat(default defaultFormat: OutputFormat) throws -> OutputFormat {
        guard let value = string("format"), !value.isEmpty else {
            return defaultFormat
        }
        guard let format = OutputFormat(rawValue: value) else {
            throw ToolArgumentError.invalid("format", value)
        }
        return format
    }

    func screenshotMode(default defaultMode: ScreenshotMode) throws -> ScreenshotMode {
        guard let value = string("mode"), !value.isEmpty else {
            return defaultMode
        }
        guard let mode = ScreenshotMode(rawValue: value) else {
            throw ToolArgumentError.invalid("mode", value)
        }
        return mode
    }

    func imageInputData(_ key: String) throws -> Data {
        guard let value = self[key] else {
            throw ToolArgumentError.missing(key)
        }
        if let dataValue = value.dataValue {
            guard NSImage(data: dataValue.1) != nil else {
                throw PicBase64Error.invalidImageData
            }
            return dataValue.1
        }
        if let input = value.stringValue, !input.isEmpty {
            return try ImageServices.decodeBase64ImageData(input)
        }
        throw ToolArgumentError.missing(key)
    }
}
