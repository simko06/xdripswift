//
//  LibreView.swift
//  xdrip
//
//  Created by Johan Degraeve on 11/09/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import os
import AVFoundation

class LibreViewFollowManager: NSObject {
    
    // MARK: - private properties
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLibreViewFollowManager)
    
    /// reference to coredatamanager
    private var coreDataManager:CoreDataManager
    
    /// reference to BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor
    
    /// delegate to pass back glucosedata
    private (set) weak var libreLinkFollowerDelegate:LibreLinkFollowerDelegate?
    
    // MARK: - initializer
        
    /// initializer
    public init(coreDataManager: CoreDataManager, libreLinkFollowerDelegate: LibreLinkFollowerDelegate) {
        
        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.libreLinkFollowerDelegate = libreLinkFollowerDelegate
        
        // call super.init
        super.init()
        
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.libreViewUrl.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.libreViewEnabled.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.libreViewPassword.rawValue, options: .new, context: nil)
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.libreViewUsername.rawValue, options: .new, context: nil)

        getReading()
        
    }
    
    // MARK: - public functions
    
    /// will get reading, only if enabled, master mode, username, password, etc.. set and tested
    public func getReading() {
        
        guard !UserDefaults.standard.isMaster, UserDefaults.standard.libreViewEnabled, UserDefaults.standard.libreViewCredentialsTested, let username = UserDefaults.standard.libreViewUsername, let password = UserDefaults.standard.libreViewPassword, let siteUrl = UserDefaults.standard.libreViewUrl else {return}
        
        
        
    }
    
    /**
     logs in to libreView

     - Parameters:
       - username: e-mail address
       - password:
       - siteUrl: domain name without path, example https://api-eu.libreview.io
       - log: OSLog instance
       - logCategory: category to use in the log
       - completion: function to be called when login finished. 4 parameters : bool with result true (success) or false (failed), two strings with title and message for alertbox to show to the user, last string is the JWT token, not nil if login was successful
     */
    public static func login(username: String, password: String, siteUrl: String, log: OSLog, logCategory: String, completion: @escaping (Bool, String, String, String?) -> Void) {
        
        if let url = URL(string: siteUrl) {
            
            let loginUrl = url.appendingPathComponent(ConstantsLibreView.libreViewLoginPath)
            
            var request = URLRequest(url: loginUrl)
            request.setValue("application/json", forHTTPHeaderField:"Content-Type")
            request.setValue("gzip", forHTTPHeaderField:"accept-encoding")
            request.setValue("Keep-Alive", forHTTPHeaderField:"connection")
            request.setValue("gzip", forHTTPHeaderField:"accept-encoding")
            
            request.setValue("llu.android", forHTTPHeaderField:"product")
            request.setValue("4.2.1", forHTTPHeaderField:"version")
            
            // it's a POST
            request.httpMethod = "POST"
            
            // create json to send
            let requestBodyAsJson: [String: Any] = [
                "email": username,
                "password": password
            ]
            
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: requestBodyAsJson, options: [])
                request.httpBody = jsonData
            } catch {
                trace("in login, failed to create json data", log: log, category: logCategory, type: .error)
                return
            }
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                
                if let error = error {
                    //completionhandler oproepen met foutboodschap
                } else if let data = data {
                    do {
                        if let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            
                            // see if there's an object with key 'data'
                            if let dataAsDictionary = jsonDictionary["data"] as? [String: Any] {
                                
                                // see if there's an object with key 'authTicket'
                                if let authTicketAsDictionary = dataAsDictionary["authTicket"] as? [String: Any] {
                                    
                                    // see if there's an object with key 'token'
                                    if let token = authTicketAsDictionary["token"] as? String {
                                        
                                        trace("found token", log: log, category: logCategory, type: .error)
                                        completion(true, TextsNightScout.verificationSuccessfulAlertTitle, "Your LibreView credentials were verified successfully.", token)
                                        
                                    } else {
                                        trace("failed to find object with key 'token'", log: log, category: logCategory, type: .error)
                                        completion(false, TextsNightScout.verificationErrorAlertTitle, "Your LibreView credentials check failed.", nil)
                                    }
                                    
                                } else {
                                    trace("failed to find object with key 'authTicket'", log: log, category: logCategory, type: .error)
                                    completion(false, TextsNightScout.verificationErrorAlertTitle, "Your LibreView credentials check failed.", nil)
                                }
                                
                            } else {
                                trace("failed to find object with key 'data'", log: log, category: logCategory, type: .error)
                                completion(false, TextsNightScout.verificationErrorAlertTitle, "Your LibreView credentials check failed.", nil)
                            }
                            
                        }
                    } catch {
                        trace("failed to deserialize data", log: log, category: logCategory, type: .error)
                        completion(false, TextsNightScout.verificationErrorAlertTitle, "Your LibreView credentials check failed.", nil)
                    }
                    
                }

            })
            
            trace("in testLibreViewCredentials, calling task.resume", log: log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info)
            
            task.resume()
            
        }
        
    }
    
    // MARK: - private functions
    
}
