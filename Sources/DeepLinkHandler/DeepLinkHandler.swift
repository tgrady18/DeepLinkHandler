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
    public let steplerAPIEndpoint = URL(string: "https://api.staging-stepler.io/v3/webhook/partners/app-install")!
    
    // API Key for Stepler
    public var apiKey: String?
    
    public init() {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            apiKey = dict["X-SERVICE-ACCOUNT-KEY"] as? String
        }
    }
    
    public func handleDeepLink(url: URL, completion: @escaping (Bool, Error?) -> Void) {
        
        print("Handling deep link: \(url)")  // Log here
        
        // Parsing logic
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            
            // Log the components for debugging
            print("URL Components: \(components)")
            
            if let queryItems = components.queryItems {
                
                // Log the query items
                print("Query items found: \(queryItems)")
                
                // Check if the URL contains the argument "stepler"
                if components.host != "stepler" {
                    print("The deep link does not contain the 'stepler' argument.")  // Log here
                    completion(false, nil)
                    return
                }
                
                var params = [String: String]()
                for item in queryItems {
                    params[item.name] = item.value
                }
                
                // Check if the required parameters are present
                guard let userId = params["userId"], let campaignId = params["partnerAppCampaignId"], let language = params["language"] else {
                    print("The deep link is missing one or more required parameters: userId, partnerAppCampaignId, language.")  // Log here
                    completion(false, nil)
                    return
                }
                
                print("Parsed params: \(params)")  // Log here
                
                // Log the required parameters
                print("userId: \(userId), partnerAppCampaignId: \(campaignId), language: \(language)")
                
                // Prepare request
                var request = URLRequest(url: steplerAPIEndpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(apiKey, forHTTPHeaderField: "X-SERVICE-ACCOUNT-KEY")
                
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
                } catch {
                    print("JSON serialization failed with error: \(error)") // Log here
                    completion(false, error)
                    return
                }
                
                // Make the API call
                let task = urlSession.dataTask(with: request) { (data, response, error) in
                    print("HTTP Response: \(String(describing: response))")  // Log here
                    
                    if let error = error {
                        print("API error: \(error)")  // Log here
                        completion(false, error)
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        print("HTTP status code: \(httpResponse.statusCode)") // Log here
                        
                        if httpResponse.statusCode == 200 {
                            // Success
                            completion(true, nil)
                            
                            // Post a notification
                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "DeepLinkSuccess"), object: nil)
                        } else {
                            print("Failed to make API call, HTTP status not 200, \(response)")
                            
                            // Log here
                            completion(false, nil)
                        }
                    }
                }
                task.resume()
            } else {
                print("No query items found in URL.")  // Log here
            }
        } else {
            print("Failed to create URLComponents from the deep link.")  // Log here
        }
    }
}
