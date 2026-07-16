import Foundation

actor DSMRequestStub {
    enum Result: Sendable {
        case timeout
        case response(Data)
    }

    private var results: [Result]
    private(set) var requestCount = 0

    init(results: [Result]) {
        self.results = results
    }

    func data(for request: URLRequest) throws -> (Data, URLResponse) {
        requestCount += 1
        guard !results.isEmpty else {
            throw URLError(.badServerResponse)
        }

        switch results.removeFirst() {
        case .timeout:
            throw URLError(.timedOut)
        case .response(let data):
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                  ) else {
                throw URLError(.badURL)
            }
            return (data, response)
        }
    }
}
