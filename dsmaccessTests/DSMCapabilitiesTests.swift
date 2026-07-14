import Testing
@testable import dsmaccess

struct DSMCapabilitiesTests {
    @Test func resolvesHighestCompatibleVersion() throws {
        var capabilities = DSMCapabilities()
        capabilities.merge([
            "SYNO.Example": APIInfoEntry(
                path: "entry.cgi",
                minVersion: 2,
                maxVersion: 5,
                requestFormat: "JSON"
            ),
        ])

        let resolved = try capabilities.resolve(
            DSMAPI("SYNO.Example", preferredVersion: 4, minimumVersion: 3)
        )

        #expect(resolved.path == "entry.cgi")
        #expect(resolved.version == 4)
        #expect(resolved.requestFormat == "JSON")
    }

    @Test func capsPreferredVersionAtServerMaximum() throws {
        var capabilities = DSMCapabilities()
        capabilities.merge([
            "SYNO.Example": APIInfoEntry(path: "example.cgi", minVersion: 1, maxVersion: 3),
        ])

        let resolved = try capabilities.resolve(
            DSMAPI("SYNO.Example", preferredVersion: 6)
        )

        #expect(resolved.version == 3)
    }

    @Test func rejectsUnsupportedVersionRange() {
        var capabilities = DSMCapabilities()
        capabilities.merge([
            "SYNO.Example": APIInfoEntry(path: "example.cgi", minVersion: 1, maxVersion: 2),
        ])

        #expect(throws: DSMError.unsupportedAPIVersion("SYNO.Example")) {
            try capabilities.resolve(DSMAPI("SYNO.Example", preferredVersion: 2, minimumVersion: 3))
        }
    }
}
