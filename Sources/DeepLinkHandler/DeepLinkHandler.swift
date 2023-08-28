//
//  File.swift
//  DeepLinkHandler
//
//  Created by Trevor (personal) on 2023-08-28.
//
import Foundation
import UIKit

public class DeepLinkHandler {
    
    // Shared Instance
    public static let shared = DeepLinkHandler()
    
    // URL Session for API Call
    public let urlSession = URLSession(configuration: .default)
    
    // Stepler API Endpoint
    public let steplerAPIEndpoint = URL(string: "https://api.stepler.io/v3/webhook/partners/app-install")!
    
    // API Key for Stepler
    public var apiKey: String?
    
    public init() {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            apiKey = dict["X-SERVICE-ACCOUNT-KEY"] as? String
        }
    }
    
    public func handleDeepLink(url: URL, completion: @escaping (Bool, Error?) -> Void) {
        
        // Parsing logic
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            var params = [String: String]()
            for item in queryItems {
                params[item.name] = item.value
            }
            
            // Prepare request
            var request = URLRequest(url: steplerAPIEndpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "X-SERVICE-ACCOUNT-KEY")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
            } catch {
                completion(false, error)
                return
            }
            
            // Make the API call
            let task = urlSession.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    // Success
                    completion(true, nil)
                    
                    // Post a notification
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "DeepLinkSuccess"), object: nil)
                } else {
                    // Failed
                    completion(false, nil)
                }
            }
            task.resume()
        }
    }
}
