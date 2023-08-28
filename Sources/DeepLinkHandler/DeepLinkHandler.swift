//
//  File.swift
//  DeepLinkHandler
//
//  Created by Trevor (personal) on 2023-08-28.
//
import Foundation
import UIKit

public class DeepLinkHandler {
    
    
    public static let shared = DeepLinkHandler()
    
    public let urlSession = URLSession(configuration: .default)
    
    public let steplerAPIEndpoint = URL(string: "https://api.staging-stepler.io/v3/webhook/partners/app-install")!
    
    public var apiKey: String?
    
    public init() {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            apiKey = dict["X-SERVICE-ACCOUNT-KEY"] as? String
        }
    }
    
    public func handleDeepLink(url: URL, completion: @escaping (Bool, Error?) -> Void) {
        
        print("Handling deep link: \(url)")  
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            
            print("URL Components: \(components)")
            
            if let queryItems = components.queryItems {
                
                print("Query items found: \(queryItems)")
                
                if components.host != "stepler" {
                    print("The deep link does not contain the 'stepler'")
                    return
                }
                
                var params = [String: String]()
                for item in queryItems {
                    params[item.name] = item.value
                }
                
                guard let userId = params["userId"], let campaignId = params["partnerAppCampaignId"], let language = params["language"] else {
                    print("The deep link is missing one or more required parameters: userId, partnerAppCampaignId, language.")
                    completion(false, nil)
                    return
                }
                
                print("Parsed params: \(params)")
                
                print("userId: \(userId), partnerAppCampaignId: \(campaignId), language: \(language)")
                
                var request = URLRequest(url: steplerAPIEndpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(apiKey, forHTTPHeaderField: "X-SERVICE-ACCOUNT-KEY")
                
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])
                } catch {
                    print("JSON serialization failed with error: \(error)")
                    completion(false, error)
                    return
                }
                
                let task = urlSession.dataTask(with: request) { (data, response, error) in
                    print("HTTP Response: \(String(describing: response))")
                    
                    if let error = error {
                        print("API error: \(error)")
                        completion(false, error)
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        print("HTTP status code: \(httpResponse.statusCode)")
                        
                        if httpResponse.statusCode == 200 {
                            completion(true, nil)
                            
                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "DeepLinkSuccess"), object: nil)
                        } else {
                            print("Failed to make API call, HTTP status not 200, \(response)")
                            
                            completion(false, nil)
                        }
                    }
                }
                task.resume()
            } else {
                print("No query items found in URL.")
            }
        } else {
            print("Failed to create URLComponents from the deep link.")
        }
    }
}
