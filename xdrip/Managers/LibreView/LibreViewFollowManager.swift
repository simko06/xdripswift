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
    
    /// dateformatter for factoryTimetamp in readings downloaded form LibreView
    private static let libreViewDateFormatter = DateFormatter.getDateFormatter(dateFormat: ConstantsLibreView.libreViewFactoryTimeStampDateFormat)
    
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

    }
    
    // MARK: - public functions
    
    /**
     logs in to libreView

     - Parameters:
       - username: e-mail address
       - password:
       - siteUrl: domain name without path, example https://api-eu.libreview.io
       - log: OSLog instance
       - logCategory: category to use in the log
       - completion: function to be called when login finished. 2 parameters :two optional strings, first is error info received from LibreView, if any. Second is the token. If token is not nil then login  was successful, and error can be ignored. If token is nil, then login failed, and optionally the errorText has additional info
     */
    public static func loginToLibreView(username: String, password: String, siteUrl: String, log: OSLog, logCategory: String, completion: @escaping (_ errorText: String?, _ token: String?) -> Void) {
        
        if let url = URL(string: siteUrl) {
            
            let loginUrl = url.appendingPathComponent(ConstantsLibreView.libreViewLoginPath)
            
            var request = URLRequest(url: loginUrl)
            request.setValue("application/json", forHTTPHeaderField:"Content-Type")
            request.setValue("gzip", forHTTPHeaderField:"accept-encoding")
            request.setValue("Keep-Alive", forHTTPHeaderField:"connection")
            request.setValue("gzip", forHTTPHeaderField:"accept-encoding")
            
            request.setValue("llu.android", forHTTPHeaderField:"product")
            request.setValue("4.7.0", forHTTPHeaderField:"version")
            
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
                completion(nil, nil)
                return
            }
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                
                if let error = error {
                    
                    trace("error = %{public}@", log: log, category: logCategory, type: .error, error.localizedDescription)
                    
                    completion(error.localizedDescription, nil)
                    
                } else if let data = data {
                    
                    //trace("data = %{public}@", log: log, category: logCategory, type: .info, String(data: data, encoding: String.Encoding.utf8)!)
                    
                    do {
                        
                        if let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            
                            // see if there's an object with key 'data'
                            if let dataAsDictionary = jsonDictionary["data"] as? [String: Any] {
                                
                                // see if there's an object with key 'authTicket'
                                if let authTicketAsDictionary = dataAsDictionary["authTicket"] as? [String: Any] {
                                    
                                    // see if there's an object with key 'token'
                                    if let token = authTicketAsDictionary["token"] as? String {
                                        
                                        trace("found token", log: log, category: logCategory, type: .info)
                                        completion(nil, token)
                                        
                                    } else {
                                        
                                        trace("failed to find object with key 'token'", log: log, category: logCategory, type: .error)
                                        completion(nil, nil)
                                        
                                    }
                                    
                                } else {
                                    
                                    trace("failed to find object with key 'authTicket'", log: log, category: logCategory, type: .error)
                                    completion(nil, nil)
                                    
                                }
                                
                            } else {
                                
                                trace("failed to find object with key 'data'", log: log, category: logCategory, type: .error)
                                
                                var errorTextInResponse:String? = nil
                                
                                // there's probably an error field
                                if let errorAsDictionary = jsonDictionary["error"] as? [String: Any] {
                                    if let messageAsString = errorAsDictionary["message"] as? String {
                                        errorTextInResponse = messageAsString
                                    }
                                }
                                
                                if let errorTextInResponse = errorTextInResponse {
                                    completion(errorTextInResponse, nil)
                                } else {
                                    completion(nil, nil)
                                }
                            }
                            
                        }
                    } catch {
                        
                        trace("failed to deserialize data", log: log, category: logCategory, type: .error)
                        completion(nil, nil)
                        
                    }
                    
                }

            })
            
            trace("in testLibreViewCredentials, calling task.resume", log: log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info)
            
            task.resume()
            
        } else {
            trace("failed to create siteUrl", log: log, category: logCategory, type: .error)
        }
        
    }
    
    /// handles all logic to get readings from Libreview (login, get patientId, etc., only if enabled, master mode, username, password, etc.. set and tested.
    /// - used from RootViewController
    /// - calls the libreLinkFollowerDelegate with the result
    public func getReading() {
        
        // check that app is in follower mode, libreView token stored, libreView enabled
        // check siteurl, token, username, password
        guard !UserDefaults.standard.isMaster, UserDefaults.standard.libreViewEnabled, UserDefaults.standard.libreViewToken != nil, let siteUrl = UserDefaults.standard.libreViewUrl, let token = UserDefaults.standard.libreViewToken, let userName = UserDefaults.standard.libreViewUsername, let password = UserDefaults.standard.libreViewPassword else {return}
        
        // piece of code used two times, called either in completionhandler or directly, see next steps
        let localClosureToGetReadings: (_ patientId: String) -> () = {patientId in
            
            LibreViewFollowManager.getReadingsFromLibreView(token: token, patientId: patientId, siteUrl: siteUrl, log: self.log, logCategory: ConstantsLog.categoryLibreViewFollowManager, completion: { followGlucoseDataArray, serialNumber, sensorStart in
                
                
                
        })}
        
        if let patientId = UserDefaults.standard.libreViewPatientId {
            
            // patientId is known, get the readings
            localClosureToGetReadings(patientId)

        } else {
                
                // first need to get the PatientId
                
                LibreViewFollowManager.getPatientIdFromLibreView(token: token, siteUrl: siteUrl, log: log, logCategory: ConstantsLog.categoryLibreViewFollowManager, completion: { (patientId: String?, errorText: String?) in
                    
                    // possibly patientId is nil, but anyway the value needs to be assigned to UserDefaults.standard.libreViewPatientId
                    UserDefaults.standard.libreViewPatientId = patientId
                    
                    if let patientId = patientId {
                        
                        // we found a patientId, go to next step which is to get the readings
                        localClosureToGetReadings(patientId)
                        
                    } else {
                        
                        // patientId not retrieved successfully.
                        // if error is due to expired jwt, then new login is required
                        if let errorText = errorText {
                            
                            if errorText.containsIgnoringCase(find: "expired jwt") {
                                
                                // set libreViewToken to nil and do a new login
                                UserDefaults.standard.libreViewToken = nil
                                
                                LibreViewFollowManager.loginToLibreView(username: userName, password: password, siteUrl: siteUrl, log: self.log, logCategory: ConstantsLog.categoryLibreViewFollowManager, completion: {(errorText: String?, token: String?) in
                                    
                                    // possibly libreViewToken is nil, but anyway the value needs to be assigned to UserDefaults.standard.libreViewPatientId
                                    UserDefaults.standard.libreViewToken = token
                                    
                                    if let token = token {
                                        LibreViewFollowManager.getPatientIdFromLibreView(token: token, siteUrl: siteUrl, log: self.log, logCategory: ConstantsLog.categoryLibreViewFollowManager, completion: { (patientId: String? ,_) in
                                            
                                            UserDefaults.standard.libreViewPatientId = patientId
                                            
                                            if let patientId = patientId {
                                                localClosureToGetReadings(patientId)
                                            }
                                            
                                        })
                                    }
                                    
                                })
                                
                            }

                        }
                        
                    }
                    
                })
                
            
        }
        
    }
        

    // MARK: - private functions
    
    /**
     gets the readings from Libreview, this is where the actual get occurs, assumes token and patientId are known

     - Parameters:
       - token: a valid token
       - patientId: the patientId
       - siteUrl: domain name without path, example https://api-eu.libreview.io
       - log: OSLog instance
       - logCategory: category to use in the log
       - completion: function to be called when finished with parameters : array of GlucoseData, first entry is the youngest - completion is only called if readings were received, ie when get was successful, serialnumber (optional), sensorStart (optional)
     */
    private static func getReadingsFromLibreView(token: String, patientId: String, siteUrl: String, log: OSLog, logCategory: String, completion: @escaping ([GlucoseData], _ serialNumber: String?, _ sensorStart: Date?) -> Void) {
          
        /// will hold the downloaded BgReading's
        var followGlucoseDataArray = [GlucoseData]()
        
        /// sensorId received from libreView
        var serialNumber: String?

        /// sensor start time stamp received from LibreView
        var sensorStart: Date?
        
        if let url = URL(string: siteUrl) {
            
            let loginUrl = url.appendingPathComponent(ConstantsLibreView.libreViewConnectionPath + "/" + patientId + "/graph")
            
            var request = URLRequest(url: loginUrl)
            request.setValue("application/json", forHTTPHeaderField:"Content-Type")
            request.setValue("gzip", forHTTPHeaderField:"accept-encoding")
            request.setValue("Keep-Alive", forHTTPHeaderField:"connection")
            request.setValue("gzip", forHTTPHeaderField:"accept-encoding")
            
            request.setValue("llu.android", forHTTPHeaderField:"product")
            request.setValue("4.7.0", forHTTPHeaderField:"version")
            
            // add the token to the request
            request.setValue("Bearer " + token, forHTTPHeaderField: "authorization")
            
            // it's a GET
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                
                if let error = error {
                    
                    trace("error = %{public}@", log: log, category: logCategory, type: .error, error.localizedDescription)
                    
                } else if let data = data {
                    
                    if let dataAsString = String(bytes: data, encoding: .utf8) {
                        trace("    data = %{public}@", log: log, category: ConstantsLog.categoryLibreViewFollowManager, type: .info, dataAsString)
                    }

                    do {
                        
                        if let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

                            if let dataAsDictionary = jsonDictionary["data"] as? [String: Any] {
                                
                                if let connectionAsDictionary = dataAsDictionary["connection"] as? [String: Any] {
                                    
                                    if let glucoseMeasurementAsDictionary = connectionAsDictionary["glucoseMeasurement"] as? [String: Any] {

                                        // see if there's an object with key 'ValueInMgPerDl'
                                        if let valueInMgPerDl = glucoseMeasurementAsDictionary["ValueInMgPerDl"] as? Int {
                                            
                                            getReadings(fromJsonDictionary: glucoseMeasurementAsDictionary, writeTo: &followGlucoseDataArray, log: log, logCategory: ConstantsLog.categoryLibreViewFollowManager, specificLogText: "glucoseMeasurement")
                                            
                                        } else {
                                            
                                            trace("failed to find object with key 'valueInMgPerDl in glucoseMeasurement'", log: log, category: logCategory, type: .error)
                                            
                                        }

                                    }
                                    
                                    
                                    
                                } else {
                                    
                                    trace("failed to find object with key 'connection'", log: log, category: logCategory, type: .error)
                                    
                                }
                                
                                // find graphdata which holds history of readings
                                if let graphDataAsArray = dataAsDictionary["graphData"] as? [Any] {
                                    
                                    for glucoseMeasurementAsDictionary in graphDataAsArray {
                                        
                                        if let glucoseMeasurementAsDictionary = glucoseMeasurementAsDictionary as? [String:Any] {
                                            
                                            if let valueInMgPerDl = glucoseMeasurementAsDictionary["ValueInMgPerDl"] as? Int {
                                                
                                                getReadings(fromJsonDictionary: glucoseMeasurementAsDictionary, writeTo: &followGlucoseDataArray, log: log, logCategory: ConstantsLog.categoryLibreViewFollowManager, specificLogText: "graphData")
                                                
                                            }
                                            
                                        }

                                    }
                                    
                                }
                                
                                // find activeSensors
                                if let activeSensorAsArray = dataAsDictionary["activeSensors"] as? [Any] {
                                    
                                    // take the first one, that should be the active sensor
                                    if let firstActiveSensorAsDictionary = activeSensorAsArray.first {
                                        if let firstActiveSensorAsDictionary = firstActiveSensorAsDictionary as? [String: Any] {
                                            if let sensorAsDictionary = firstActiveSensorAsDictionary["sensor"] as? [String: Any] {
                                                if let newSerialNumber = sensorAsDictionary["sn"] as? String? {
                                                    serialNumber = newSerialNumber
                                                }
                                                if let sensorStartAsInt = sensorAsDictionary["a"] as? Int {
                                                    let sensorStartAsDate = Date(timeIntervalSince1970: TimeInterval(sensorStartAsInt))
                                                }
                                            }

                                        }
                                    }
                                }

                            } else {
                                
                                trace("failed to find object with key 'data'", log: log, category: logCategory, type: .error)
                                
                                var errorTextInResponse:String? = nil
                                
                                // there's probably an error field
                                if let messageAsString = jsonDictionary["message"] as? String {
                                    errorTextInResponse = messageAsString
                                }

                                if let errorTextInResponse = errorTextInResponse {
                                        
                                    trace("errorText %{public}@", log: log, category: logCategory, type: .error, errorTextInResponse)

                                }
                            }
                            
                        }
                        
                    } catch {
                        
                        trace("failed to deserialize data", log: log, category: logCategory, type: .error)
                        
                    }
                    
                }
                
                // call completion handler, possibly with empty followGlucoseDataArray and with nil values for serialNumber and sensorStart
                completion(followGlucoseDataArray, serialNumber, sensorStart)

            })
            
            trace("in getReadingsFromLibreView, calling task.resume", log: log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info)
            
            task.resume()
            
        } else {
            
            trace("failed to create siteUrl", log: log, category: logCategory, type: .error)
            
        }

    
    }

    /**
            gets patient id from libreView
     - Parameters:
            - token : the token to connect to libreView, was retrieved during previous login session
            - siteUrl: domain name without path, example https://api-eu.libreview.io
            - log: OSLog instance
            - logCategory: category to use in the log
            - completion: function to be called when login finished.  parameters : optional string that has the patientId, if nil then get failed, optional string with error text, nil if patientId not nil (because get was successful in that case)
     */
    private static func getPatientIdFromLibreView(token: String, siteUrl: String, log: OSLog, logCategory: String, completion: @escaping (String?, String?) -> Void) {
        
        if let url = URL(string: siteUrl) {
            
            let loginUrl = url.appendingPathComponent(ConstantsLibreView.libreViewConnectionPath)
            
            var request = URLRequest(url: loginUrl)
            request.setValue("application/json", forHTTPHeaderField:"Content-Type")
            request.setValue("gzip", forHTTPHeaderField:"accept-encoding")
            request.setValue("Keep-Alive", forHTTPHeaderField:"connection")
            request.setValue("gzip", forHTTPHeaderField:"accept-encoding")
            
            request.setValue("llu.android", forHTTPHeaderField:"product")
            request.setValue("4.7.0", forHTTPHeaderField:"version")
            
            // add the token to the request
            request.setValue("Bearer " + token, forHTTPHeaderField: "authorization")
            
            // it's a GET
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                
                if let error = error {
                    
                    trace("error = %{public}@", log: log, category: logCategory, type: .error, error.localizedDescription)
                    
                    completion(nil, "error received = " + error.localizedDescription)
                    
                } else if let data = data {
                    
                    do {
                        
                        if let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

                            if let dataAsArray = jsonDictionary["data"] as? [Any] {
                                
                                for entry in dataAsArray {
                                    
                                    if let entry = entry as? [String:Any] {
                                        
                                        if let patientId = entry["patientId"] as? String {
                                            
                                            trace("found patientid %{public}@", log: log, category: logCategory, type: .info, patientId)
                                            completion(patientId, nil)
                                            
                                        }
                                        
                                    }
                                    
                                }
                                
                            } else {
                                
                                trace("failed to find object with key 'data'", log: log, category: logCategory, type: .error)
                                
                                var errorTextInResponse:String? = nil
                                
                                // there's probably an error field
                                if let messageAsString = jsonDictionary["message"] as? String {
                                    errorTextInResponse = messageAsString
                                }

                                if let errorTextInResponse = errorTextInResponse {
                                        
                                    completion(nil, errorTextInResponse)

                                } else {
                                   
                                    completion(nil, "unknown error")
                                }
                            }
                            
                        }
                    } catch {
                        
                        trace("failed to deserialize data", log: log, category: logCategory, type: .error)
                        
                        completion(nil, "failed to deserialize data")
                        
                    }
                    
                }

            })
            
            trace("in getPatientId, calling task.resume", log: log, category: ConstantsLog.categoryNightScoutSettingsViewModel, type: .info)
            
            task.resume()
            
        } else {
            
            trace("failed to create siteUrl", log: log, category: logCategory, type: .error)
            
            completion(nil, "failed to create siteUrl")
            
        }

    }
    
    /**
    Piece of code used two times. Gets array of GlucoseData
     - parameters:
        - fromJsonDictionary: a glucoseMeasurement json dictionary
        - writeTo: array of GlucoseData to which readings should be written, chronologically, youngest element the first. The array may already have elements.
        - log
        - logCategory
        - specificLogText:
     */
    private static func getReadings(fromJsonDictionary: [String: Any], writeTo: inout [GlucoseData], log: OSLog, logCategory: String, specificLogText: String) {
        
        if let valueInMgPerDl = fromJsonDictionary["ValueInMgPerDl"] as? Int {
            
            trace("found valueInMgPerDl = %{public}@ in %{public}@", log: log, category: logCategory, type: .info, valueInMgPerDl.description, specificLogText)

            if let factoryTimestamp = fromJsonDictionary["FactoryTimestamp"] as? String {
                
                trace("found factoryTimestamp = %{public}@", log: log, category: logCategory, type: .info, factoryTimestamp)
                
                // create reading and insert in followGlucoseDataArray
                if let newReading = GlucoseData(timeStamp: factoryTimestamp, sgv: valueInMgPerDl, dateFormatter: libreViewDateFormatter) {
                 
                    newReading.insertChronologically(into: &writeTo)
                    
                }

            }
            
        }
        
    }
    
}
