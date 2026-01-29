import XCTest
@testable import IzmirDatas

final class IzmirDatasTests: XCTestCase {
    func testCSVParserParsesSemicolonDelimitedStops() throws {
        let csv = """
        Durak ID;Durak Adı;Enlem;Boylam;Hatlar
        1001;\"Konak; İskele\";38,419;27,128;12,33,44
        1002;Alsancak;38.432;27.141;5|6|7
        """
        let table = try CSVParser.parse(data: Data(csv.utf8))
        XCTAssertEqual(table.headers.count, 5)
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.rows[0]["Durak ID"], "1001")
        XCTAssertEqual(table.rows[0]["Durak Adı"], "Konak; İskele")
        XCTAssertEqual(table.rows[1]["Boylam"], "27.141")
    }

    func testKeyNormalizerNormalizesTurkishHeaders() {
        XCTAssertEqual(KeyNormalizer.normalize("Hat Numarası"), "hat_numarasi")
        XCTAssertEqual(KeyNormalizer.normalize("Duraktan Geçen Hatlar"), "duraktan_gecen_hatlar")
        XCTAssertEqual(KeyNormalizer.normalize("ENLEM"), "enlem")
    }

    func testPersistenceControllerRoundTripInMemory() throws {
        let persistence = PersistenceController(inMemory: true)
        let key = "test_dataset"
        let payload = Data("hello".utf8)
        let now = Date()

        try persistence.saveDatasetPayload(datasetKey: key, payload: payload, lastUpdated: now)
        let loaded = try persistence.loadDatasetPayload(datasetKey: key)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.payload, payload)
        if let loadedDate = loaded?.lastUpdated {
            XCTAssertEqual(loadedDate.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.5)
        }
    }

    func testCKANResolverPrefersCSVResource() async throws {
        let session = makeStubbedSession { request in
            let body = """
            {
              \"success\": true,
              \"result\": {
                \"resources\": [
                  {\"url\": \"https://example.com/a.pdf\", \"format\": \"PDF\", \"name\": \"pdf\"},
                  {\"url\": \"https://example.com/data.csv\", \"format\": \"CSV\", \"name\": \"csv\"}
                ]
              }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        let apiClient = APIClient(session: session)
        let resolver = CKANResolver(apiClient: apiClient)
        let url = try await resolver.resolveBestResourceURL(datasetID: "any", preferredFormats: ["CSV"])
        XCTAssertEqual(url.absoluteString, "https://example.com/data.csv")
    }
}

private final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            XCTFail("requestHandler not set")
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeStubbedSession(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
    URLProtocolStub.requestHandler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    return URLSession(configuration: configuration)
}
