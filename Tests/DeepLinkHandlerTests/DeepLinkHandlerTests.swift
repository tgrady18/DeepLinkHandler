import XCTest
@testable import DeepLinkHandler

final class DeepLinkHandlerTests: XCTestCase {
    private var urlSession: FakeURLSession!
    private var sut: DeepLinkHandler!
    
    private let voidHandler: DeepLinkHandler.CompletionHandler =  { _,_ in }
    
    override func setUp() {
        urlSession = FakeURLSession()
        sut = DeepLinkHandler(urlSession: urlSession)
    }
    
    // Given:   A valid Stepler URL
    // When:    Attempting to handle it and system responds with status code 200
    // Then:    An attempt to send the request to stepler should be made
    func test_valid_url_successful_response() {
        urlSession.setResponse()
        let expectation = expectation(description: "Completion handler called")
        
        sut.handleDeepLink(url: testURL()) { success, error in
            XCTAssertNil(error, error.debugDescription)
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // Given:   A valid Stepler URL
    // When:    Attempting to handle it and system responds with status code 400
    // Then:    An attempt to send the request to stepler should be made
    func test_valid_url_failed_response() {
        let simulatedCode = 400
        urlSession.setResponse(statusCode: simulatedCode)
        let expectation = expectation(description: "Completion handler called")
        
        sut.handleDeepLink(url: testURL()) { success, error in
            guard case let DeepLinkHandlerError.httpError(statusCode) = (error as! DeepLinkHandlerError) else {
                XCTFail("Expected error code")
                return
            }
            XCTAssertEqual(statusCode, simulatedCode)
            XCTAssertFalse(success)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // Given:   A Stepler URL missing parameters
    // When:    Attempting to handle it
    // Then:    An error should be received indicating that some parameters are missing
    func test_missing_query_parameters() {
        let url = URL(string: "http://stepler")!
        let expectation = expectation(description: "Completion handler called")
        
        sut.handleDeepLink(url: url) { success, error in
            guard case .missingQueryItems = error as? DeepLinkHandlerError else {
                XCTFail("Expected error code")
                return
            }
            XCTAssertFalse(success)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // Given:   A Stepler URL missing specific parameters
    // When:    Attempting to handle it
    // Then:    An error should be received indicating that some parameters are missing
    func test_missing_specific_query_parameter() {
        let expectation = expectation(description: "Completion handler called")
        
        sut.handleDeepLink(url: testURL(userId: nil)) { success, error in
            guard case .missingQueryItems = error as? DeepLinkHandlerError else {
                XCTFail("Expected error code")
                return
            }
            XCTAssertFalse(success)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // Given:   An invalid URL
    // When:    Attempting to handle it
    // Then:    An error should be received indicating that it's not a Stepler URL
    func test_empty_URL() {
        let expectation = expectation(description: "Completion handler called")
        
        sut.handleDeepLink(url: URL(string: "http://google.com")!) { success, error in
            guard case .notSteplerLink = error as? DeepLinkHandlerError else {
                XCTFail("Expected error code")
                return
            }
            XCTAssertFalse(success)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // Given:   An invalid Stepler URL
    // When:    Attempting to handle it
    // Then:    An error should be received indicating that it's not a correct URL
    func test_invalid_URL() {
        let expectation = expectation(description: "Completion handler called")
        
        sut.handleDeepLink(url: URL(string: "http://google.com")!) { success, error in
            guard case .notSteplerLink = error as? DeepLinkHandlerError else {
                XCTFail("Expected error code")
                return
            }
            XCTAssertFalse(success)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    // Given:   An valid Stepler URL
    // When:    Attempting to handle it and a networking error occurs
    // Then:    The error should be propagated
    func test_networking_error() {
        let domain = "Test"
        let code = -1000
        let error = NSError(domain: domain, code: code, userInfo: nil)
        urlSession.response = (200, nil, error)
        
        let expectation = expectation(description: "Completion handler called")
        
        sut.handleDeepLink(url: testURL()) { success, error in
            XCTAssertEqual((error as? NSError)?.domain, domain)
            XCTAssertEqual((error as? NSError)?.code, code)
            XCTAssertFalse(success)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    private func testURLComponents(userId: String? = "2", campaignId: String? = "12", language: String? = "en") -> URLComponents {
        var queryItems = [URLQueryItem]()
        
        if let userId {
            queryItems.append(URLQueryItem(name: sut.userIdKey, value: userId))
        }
        
        if let campaignId {
            queryItems.append(URLQueryItem(name: sut.campaignKey, value: campaignId))
        }
        
        if let language {
            queryItems.append(URLQueryItem(name: sut.languageKey, value: language))
        }
        
        var components =  URLComponents(string: "http://stepler")!
        components.queryItems = queryItems
        return components
    }
    
    private func testURL(userId: String? = "2", campaignId: String? = "12", language: String? = "en") -> URL {
        return testURLComponents(userId: userId, campaignId: campaignId, language: language).url!
    }
}

private class FakeURLSession: URLSession {
    var dataTask: FakeURLSessionDataTask?
    var response: (Int, Data?, Error?)?
    
    override init() { }
    
    func setResponse(statusCode: Int = 200, data: Data? = nil, error: Error? = nil) {
        response = (statusCode, data, error)
    }
    
    override func dataTask(with request: URLRequest, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        dataTask = FakeURLSessionDataTask(request: request, response: response, completionHandler: completionHandler)
        return dataTask!
    }
}

private class FakeURLSessionDataTask: URLSessionDataTask {
    var request: URLRequest?
    var completionHandler: ((Data?, URLResponse?, Error?) -> Void)?
    var responseDetails: (statusCode: Int, data: Data?, error: Error?)?
    var url: URL?
    
    init(request: URLRequest, response: (Int, Data?, Error?)?, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        self.request = request
        self.responseDetails = response
        self.completionHandler = completionHandler
    }
    
    override func resume() {
        if let responseDetails, let request, let completionHandler {
            let response = HTTPURLResponse(url: request.url!, statusCode: responseDetails.statusCode, httpVersion: "1.0", headerFields: [:])
            completionHandler(responseDetails.data, response, responseDetails.error)
        }
    }
}

