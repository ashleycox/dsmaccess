import Foundation
import Testing
@testable import dsmaccess

struct AdministrationModelsTests {
    @Test func decodesAccountValuesAcrossDSMTypes() throws {
        let data = Data(
            #"""
            {
              "name": "alex",
              "desc": "Compte local",
              "uid": "1031",
              "expired": "normal",
              "groups": ["users", "administrators"],
              "is_admin": 1
            }
            """#.utf8
        )

        let user = try JSONDecoder().decode(DSMUser.self, from: data)

        #expect(user.name == "alex")
        #expect(user.uid == 1031)
        #expect(user.isAdministrator)
        #expect(!user.isDisabled)
    }

    @Test func decodesDownloadTransferNumbersFromStrings() throws {
        let data = Data(
            #"""
            {
              "id": "dbid_1",
              "title": "archive.zip",
              "size": "1000",
              "status": "downloading",
              "additional": {
                "transfer": {
                  "size_downloaded": "250",
                  "size_uploaded": 12,
                  "speed_download": "2048",
                  "speed_upload": 0
                }
              }
            }
            """#.utf8
        )

        let task = try JSONDecoder().decode(DownloadTask.self, from: data)

        #expect(task.size == 1_000)
        #expect(task.downloaded == 250)
        #expect(task.progress == 0.25)
        #expect(task.downloadSpeed == 2_048)
        #expect(task.canPause)
    }
}
