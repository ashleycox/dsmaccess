import Foundation
import Testing
@testable import dsmaccess

struct NASProfileTests {
    @Test func decodesALegacyDirectProfile() throws {
        let data = Data(
            #"{"id":"7E598DB5-744F-45D0-9404-8A47ECABCA4F","name":"Studio NAS","host":"nas.local","port":5001,"useHTTPS":true,"account":"alex","remembersPassword":true}"#.utf8
        )

        let profile = try JSONDecoder().decode(NASProfile.self, from: data)

        #expect(profile.connection == .direct(DSMEndpoint(
            useHTTPS: true,
            host: "nas.local",
            port: 5_001
        )))
        #expect(profile.displayName == "Studio NAS")
        #expect(profile.remembersPassword)
    }

    @Test func roundTripsAQuickConnectProfileWithoutSavingItsTemporaryRoute() throws {
        let profile = NASProfile(
            name: "Studio NAS",
            connection: .quickConnect(id: "My-NAS"),
            account: "alex",
            remembersPassword: true
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(NASProfile.self, from: data)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(decoded == profile)
        #expect(object["host"] == nil)
        #expect(object["port"] == nil)
        #expect(object["useHTTPS"] == nil)
    }
}
