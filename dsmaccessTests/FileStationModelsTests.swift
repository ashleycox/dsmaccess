import Foundation
import Testing
@testable import dsmaccess

@MainActor
struct FileStationModelsTests {
    @Test func safelyEncodesPathArrays() throws {
        let encoded = try DSMParameter.json([
            "/documents/rapport \"final\".pdf",
            "/photos/été\n2026.jpg",
        ])

        let value = try encoded.encoded(for: nil)
        let decoded = try JSONDecoder().decode([String].self, from: Data(value.utf8))
        #expect(decoded == [
            "/documents/rapport \"final\".pdf",
            "/photos/été\n2026.jpg",
        ])
    }

    @Test func decodesDetailedFileMetadata() throws {
        let data = Data(
            #"""
            {
              "name": "rapport.pdf",
              "path": "/documents/rapport.pdf",
              "isdir": false,
              "additional": {
                "size": 4096,
                "type": "application/pdf",
                "real_path": "/volume1/documents/rapport.pdf",
                "time": { "mtime": 1710000000, "atime": 1710000100, "crtime": 1700000000 },
                "owner": { "user": "mathieu", "group": "users" },
                "perm": { "posix": 644, "acl": { "read": true, "write": true, "del": false } }
              }
            }
            """#.utf8
        )

        let item = try JSONDecoder().decode(FileStationItem.self, from: data)

        #expect(item.name == "rapport.pdf")
        #expect(item.additional?.size == 4096)
        #expect(item.additional?.owner?.user == "mathieu")
        #expect(item.additional?.permission?.acl?.delete == false)
        #expect(item.additional?.realPath == "/volume1/documents/rapport.pdf")
    }

    @Test func streamsMultipartBodiesAndSanitizesFilenames() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dsmaccess-multipart-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("rapport\"\r\nX-Injected: oui.txt")
        try Data("contenu".utf8).write(to: source)
        let bodyURL = try await MultipartBodyFile.create(
            fields: ["path": "/volume1/documents"],
            fileURL: source,
            fileFieldName: "file",
            boundary: "test-boundary"
        )
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        let data = try await MultipartBodyFile.readData(at: bodyURL)
        let body = try #require(String(data: data, encoding: .utf8))
        #expect(body.contains("filename=\"rapport___X-Injected: oui.txt\""))
        #expect(!body.contains("\r\nX-Injected: oui.txt"))
        #expect(body.contains("\r\n\r\ncontenu\r\n--test-boundary--\r\n"))
    }
}
