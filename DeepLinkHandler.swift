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
    private let urlSession = URLSession(configuration: .default)
    
    // API Endpoint
    private var apiEndpoint: URL?
    
    private init() {}
    
    // Setup API endpoint
    public func setup(apiEndpoint: String) {
        self.apiEndpoint = URL(string: apiEndpoint)
    }
    
    // Handle DeepLink
    public func handleDeepLink(url: URL) {
        guard let apiEndpoint = apiEndpoint else {
            print("API Endpoint is not set.")
            return
        }
        
        // Parsing logic
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            var params = [String: String]()
            for item in queryItems {
                params[item.name] = item.value
            }
            
            // Forwarding to API
            var request = URLRequest(url: apiEndpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
            } catch {
                print("Error creating JSON payload.")
                return
            }
            
            let task = urlSession.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                }
                // Further logic if needed
            }
            task.resume()
        }
    }
}
