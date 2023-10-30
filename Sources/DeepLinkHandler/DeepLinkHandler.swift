//
//  File.swift
//  DeepLinkHandler
//
//  Created by Trevor (personal) on 2023-08-28.
//
import Foundation

enum DeepLinkHandlerError: Error {
    case missingURLComponents // Failed to create URLComponents from the deep link
    case missingQueryItems // The deep link is missing one or more required parameters: userId, partnerAppCampaignId, language
    case notSteplerLink // The deep link host is not 'stepler'
    case unexpectedResponse // The response were of an unexpected type
    case httpError(statusCode: Int?) // Unexpected http status code
}

struct DeepLinkHandler {
    typealias Printer = (String) -> Void
    typealias CompletionHandler = (Bool, Error?) -> Void
    
    let userIdKey = "userId"
    let campaignKey = "partnerAppCampaignId"
    let languageKey = "language"
    let steplerAPIEndpoint = URL(string: "https://api.staging-stepler.io/v3/webhook/partners/app-install")!
    
    private let urlSession: URLSession
    private let printFunction: Printer
    
    public init(urlSession: URLSession = URLSession(configuration: .default),
                printFunction: @escaping Printer = { _ in }) {
        self.urlSession = urlSession
        self.printFunction = printFunction
    }
    
    public func handleDeepLink(url: URL, completion: @escaping CompletionHandler) {
        printFunction("Handling deep link: \(url)")
        
        let params: [String: String]
        do {
            params = try getQueryParamters(url: url)
            try validate(queryParameters: params)
        } catch let error {
            completion(false, error)
            return
        }
        
        sendRequest(parameters: params, completionHandler: completion)
    }
    
    private func getQueryParamters(url: URL) throws -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw DeepLinkHandlerError.missingURLComponents
        }
        printFunction("URL Components: \(components)")
        
        guard components.host == "stepler" else {
            throw DeepLinkHandlerError.notSteplerLink
        }
        
        guard let queryItems = components.queryItems else {
            throw DeepLinkHandlerError.missingQueryItems
        }
        printFunction("Query items found: \(queryItems)")
        
        var params = [String: String]()
        for item in queryItems {
            params[item.name] = item.value
        }
        printFunction("Parsed params: \(params)")
        
        return params
    }
    
    private func validate(queryParameters params: [String: String]) throws {
        guard let userId = params[userIdKey],
              let campaignId = params[campaignKey],
              let language = params[languageKey] else {
            throw DeepLinkHandlerError.missingQueryItems
        }
        printFunction("""
                      \(userIdKey): \(userId),
                      \(campaignKey): \(campaignId),
                      \(languageKey): \(language)
                      """)
    }
    
    private func sendRequest(parameters params: [String: String],
                             completionHandler: @escaping CompletionHandler)
    {
        var request = URLRequest(url: steplerAPIEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey(), forHTTPHeaderField: "X-SERVICE-ACCOUNT-KEY")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
        } catch {
            printFunction("JSON serialization failed with error: \(error)")
            completionHandler(false, error)
            return
        }
        
        let task = urlSession.dataTask(with: request) { (data, response, error) in
            printFunction("HTTP Response: \(String(describing: response))")
            
            do {
                try validate(data: data, response: response, error: error)
                completionHandler(true, nil)
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "DeepLinkSuccess"), object: nil) //TODO: Extract or remove - no part of the API or documentation indicates this

            } catch (let error) {
                completionHandler(false, error)
            }
        }
        task.resume()
    }
    
    private func apiKey() -> String? {
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] else {
            return nil
        }
        return dict["X-SERVICE-ACCOUNT-KEY"] as? String
    }
    
    private func validate(data: Data?, response: URLResponse?, error: Error?) throws {
        guard error == nil else {
            printFunction("API error: \(error.debugDescription)")
            throw error!
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepLinkHandlerError.unexpectedResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            printFunction("Failed to make API call, HTTP status not 200, \(response.debugDescription)")
            throw DeepLinkHandlerError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}
