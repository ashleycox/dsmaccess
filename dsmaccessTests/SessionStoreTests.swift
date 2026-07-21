import Testing
@testable import dsmaccess

@MainActor
struct SessionStoreTests {
    @Test func reconnectionNoticeLivesUntilDismissedOrSessionCleared() {
        let session = SessionStore()
        #expect(session.reconnectionNotice == nil)

        session.publishAutomaticReconnectionNotice()
        let notice = session.reconnectionNotice
        #expect(notice?.isEmpty == false)

        session.dismissReconnectionNotice()
        #expect(session.reconnectionNotice == nil)

        // Un avis encore affiché ne doit pas survivre à une déconnexion : il serait
        // présenté hors contexte à la session suivante.
        session.publishAutomaticReconnectionNotice()
        session.clear()
        #expect(session.reconnectionNotice == nil)
    }

    @Test func withClientRejectsWorkAfterLogoutWithoutFakingAnExpiry() async {
        let session = SessionStore()
        do {
            _ = try await session.withClient { _ in }
            Issue.record("Sans session, withClient aurait dû échouer.")
        } catch {
            #expect(DSMError.isCancellation(error))
            #expect(session.disconnectionMessage == nil)
        }
    }
}
