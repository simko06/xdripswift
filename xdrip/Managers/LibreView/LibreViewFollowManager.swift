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
    private static let libreViewDateFormatter = {
        var dateFormatter = DateFormatter.getDateFormatter(dateFormat: ConstantsLibreView.libreViewFactoryTimeStampDateFormat)
        dateFormatter.timeZone = TimeZone(identifier: ConstantsLibreView.libreViewFactoryTimeStampTimeZone)
        return dateFormatter
    }()
    
    
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
                
                // need to take a copy because followGlucoseDataArray is immutable
                var copyFollowGlucoseDataArray = Array(followGlucoseDataArray)
                
                // fill up gaps either with values stored in UserDefaults or using GlucoseData.fill0Gaps
                LibreViewFollowManager.completeGlucoseData(arrayToComplete: &copyFollowGlucoseDataArray, log: self.log, logCategory: ConstantsLog.categoryLibreViewFollowManager)
                
                // call libreLinkFollowerInfoReceived in main thread
                DispatchQueue.main.sync {

                    self.libreLinkFollowerDelegate?.libreLinkFollowerInfoReceived(followGlucoseDataArray: &copyFollowGlucoseDataArray, serialNumber: serialNumber, sensorStart: sensorStart)

                }
                
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
                        trace("    data = %{public}@", log: log, category: ConstantsLog.categoryLibreViewFollowManager, type: .debug, dataAsString)
                    }

                    do {
                        
                        if let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {

                            if let dataAsDictionary = jsonDictionary["data"] as? [String: Any] {
                                
                                if let connectionAsDictionary = dataAsDictionary["connection"] as? [String: Any] {
                                    
                                    if let glucoseMeasurementAsDictionary = connectionAsDictionary["glucoseMeasurement"] as? [String: Any] {

                                        getReadings(fromJsonDictionary: glucoseMeasurementAsDictionary, writeTo: &followGlucoseDataArray, log: log, logCategory: ConstantsLog.categoryLibreViewFollowManager, specificLogText: "glucoseMeasurement")

                                    }
                                    
                                    
                                    
                                } else {
                                    
                                    trace("failed to find object with key 'connection'", log: log, category: logCategory, type: .error)
                                    
                                }
                                
                                // find graphdata which holds history of readings
                                if let graphDataAsArray = dataAsDictionary["graphData"] as? [Any] {
                                    
                                    for glucoseMeasurementAsDictionary in graphDataAsArray {
                                        
                                        if let glucoseMeasurementAsDictionary = glucoseMeasurementAsDictionary as? [String:Any] {
                                            
                                                getReadings(fromJsonDictionary: glucoseMeasurementAsDictionary, writeTo: &followGlucoseDataArray, log: log, logCategory: ConstantsLog.categoryLibreViewFollowManager, specificLogText: "graphData")
                                            
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
                                                    sensorStart = Date(timeIntervalSince1970: TimeInterval(sensorStartAsInt))
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
            
            if let factoryTimestamp = fromJsonDictionary["FactoryTimestamp"] as? String {
                
                // create reading and insert in followGlucoseDataArray
                if let newReading = GlucoseData(timeStamp: factoryTimestamp, sgv: valueInMgPerDl, dateFormatter: libreViewDateFormatter) {
                    trace("    newreading created with value %{public}@ and timestamp %{public}@", log: log, category: ConstantsLog.categoryLibreViewFollowManager, type: .info, valueInMgPerDl.description, factoryTimestamp)
                
                    newReading.insertChronologically(into: &writeTo)
                    
                }

            }
            
        }
        
    }
    
    /// Make sure glucose data array has 70 minutes of readings.
    /// - Fill up gaps with values retrieved from UserDefaults.standard.previousRawGlucoseValues where possible
    /// - If there's still 0 gaps, then fill them up with the function GlucoseData.fill0Gaps, with maxwidth of 30 minutes. Normally 15 minutes should be enough because LibreView returns the history per 15 minutes.
    private static func completeGlucoseData(arrayToComplete: inout [GlucoseData], log: OSLog, logCategory: String) {

        // if prevoiusRawGlucoseValues is empty, then intialize this first
        let previousRawGlucoseValueTimeStampAsInt: Int64 = UserDefaults.standard.previousRawGlucoseValueTimeStamp?.toSecondsAsInt64() ?? 0
        var previousRawGlucoseValues: [Int] = UserDefaults.standard.previousRawGlucoseValues ?? [Int]()

        // to iterate through arrayToComplete, just as long as we don't hit the end
        // we will not use the first element in the array (ie with index 0), because we know that's the latest one, so start with index 1
        var arrayToCompleteIndex = 1
        
        // iterate through all elements in arrayToCompleteIndex
        // as we find 'gaps' (ie minutes for which there's no readings), fill up with 0
        loop1: while arrayToCompleteIndex <= arrayToComplete.count - 1 {
            
            //trace("ARRAY TRACE - in loop1, arrayToComplete.count - 1 = %{public}@", log: log, category: logCategory, type: .info, (arrayToComplete.count - 1).description)

            // starting from arrayToComplete[arrayToCompleteIndex - 1] (ie the previous element)
            // take the timestamp of that element and substract 60 seconds
            // then compare with the timestamp of arrayToComplete[arrayToCompleteIndex], difference should be max 5 seconds (5 seconds because Libre readings tend to come on different seconds, or not?)
            
            // timestamp of the previous element in arrayToComplete, to which we compare the timestamp
            let timeStampOfElementToWhichComparisonIsDoneAsInt = arrayToComplete[arrayToCompleteIndex - 1].timeStamp.toSecondsAsInt64()

            if abs(arrayToComplete[arrayToCompleteIndex].timeStamp.toSecondsAsInt64() - (timeStampOfElementToWhichComparisonIsDoneAsInt - 60)) > 30 {
                
                // the element at arrayToCompleteIndex is more than 1 minute earlier than the previous one
                // here we need to insert an element
                
                // first try to find an element in previousRawGlucoseValues, that has a timestamp less than 5 seconds differing
                // if we don't find one, then add an entry with glucosedata value 0
                
                //trace("ARRAY TRACE - inserting 0.0 element", log: log, category: logCategory, type: .info)
                //trace("ARRAY TRACE - timeStampOfElementToWhichComparisonIsDoneAsInt = %{public}@", log: log, category: logCategory, type: .info, arrayToComplete[arrayToCompleteIndex - 1].timeStamp.description(with: .current))
                //traceGlucoseArray(totrace: arrayToComplete.map{Int($0.glucoseLevelRaw)}, log: log, logCategory: logCategory, infoString: "arraytocomplete before insert")
                
                arrayToComplete.insert(GlucoseData(timeStamp: Date(timeIntervalSince1970: Double(timeStampOfElementToWhichComparisonIsDoneAsInt) - 60.0), glucoseLevelRaw: 0.0), at: arrayToCompleteIndex)
                //traceGlucoseArray(totrace: arrayToComplete.map{Int($0.glucoseLevelRaw)}, log: log, logCategory: logCategory, infoString: "arraytocomplete after insert")

                
                //trace("ARRAY TRACE - inserted element has timestamp                   = %{public}@", log: log, category: logCategory, type: .info, arrayToComplete[arrayToCompleteIndex].timeStamp.description(with: .current))

                // increase arrayToCompleteIndex with 1,
                //arrayToCompleteIndex += 1

                arrayToCompleteIndex += 1
                
                continue loop1
                
            }
            
            arrayToCompleteIndex += 1
            
            if arrayToCompleteIndex >= ConstantsLibreSmoothing.amountOfPreviousReadingsToStoreForLibreView {
                // we have enough elements
                break loop1
            }
            
        }
        
        /* fill 0 values in previousRawGlucoseValues with values found in arrayToComplete
         then do the opposite, replace 0 values in arrayToComplete with values found in previousRawGlucoseValues
        */
        
        traceGlucoseArray(totrace: arrayToComplete.map{Int($0.glucoseLevelRaw)}, log: log, logCategory: logCategory, infoString: "arrayToComplete          before process start")
        traceGlucoseArray(totrace: previousRawGlucoseValues                    , log: log, logCategory: logCategory, infoString: "previousRawGlucoseValues before process start")

        // start the process
        if let first = arrayToComplete.first {

            // two variables needed in that process:
            let timeDifference = first.timeStamp.toSecondsAsInt64() - previousRawGlucoseValueTimeStampAsInt
            let indexDifference = Int(round(Double(timeDifference)/Double(60)))
            var index = 0

            trace("indexDifference = %{public}@", log: log, category: logCategory, type: .info, indexDifference.description)
            
            // first replace 0 values in previousRawGlucoseValues with values found in arrayToComplete
            
            // the element at index in previousRawGlucoseValues corresponds (in time) to the value at indexDifference in arrayToComplete
            while index < previousRawGlucoseValues.count && index + indexDifference < arrayToComplete.count {
                if previousRawGlucoseValues[index] == 0 {
                    previousRawGlucoseValues[index] = Int(arrayToComplete[index + indexDifference].glucoseLevelRaw)
                }
                index += 1
            }
            
            // previousRawGlucoseValues may be shorter dan amountOfPreviousReadingsToStoreForLibreView
            // append missing values, to come to an amount amountOfPreviousReadingsToStoreForLibreView - indexDifference, because we'll prepend the first missing values later
            while previousRawGlucoseValues.count < ConstantsLibreSmoothing.amountOfPreviousReadingsToStoreForLibreView - indexDifference && index + indexDifference < arrayToComplete.count {
                
                previousRawGlucoseValues.append(Int(arrayToComplete[index + indexDifference].glucoseLevelRaw))
                index += 1
                
            }
            
            // now prepend values from arrayToComplete
            for index in (0...indexDifference).dropLast().reversed() {
                previousRawGlucoseValues.insert(Int(arrayToComplete[index].glucoseLevelRaw), at: 0)
            }
            
            // assign new previousRawGlucoseValues and also the timestamp of the youngest element to userdefaults
            UserDefaults.standard.previousRawGlucoseValues = previousRawGlucoseValues
            UserDefaults.standard.previousRawGlucoseValueTimeStamp = arrayToComplete[0].timeStamp

            // now do the opposite, replace 0 value in arrayToComplete with values from previousRawGlucoseValues
            
            index = 0
            
            // the first element in previousRawGlucoseValues corresponds to the first element in arrayToComplete (qua timing)
            while index < previousRawGlucoseValues.count && index < arrayToComplete.count {
                
                if arrayToComplete[index].glucoseLevelRaw == 0.0 {
                    
                    arrayToComplete[index].glucoseLevelRaw = Double(previousRawGlucoseValues[index])
                    
                }
                
                index += 1
                
            }

        }

        traceGlucoseArray(totrace: arrayToComplete.map{Int($0.glucoseLevelRaw)}, log: log, logCategory: logCategory, infoString: "arrayToComplete          after process start")
        traceGlucoseArray(totrace: previousRawGlucoseValues                    , log: log, logCategory: logCategory, infoString: "previousRawGlucoseValues after process start")

        traceGlucoseArray(totrace: arrayToComplete.map{Int($0.glucoseLevelRaw)}, log: log, logCategory: logCategory, infoString: "before fill0gaps")

        // fill up gaps, ie entries where rawvalue = 0
        arrayToComplete.fill0Gaps(maxGapWidth: 30)

        traceGlucoseArray(totrace: arrayToComplete.map{Int($0.glucoseLevelRaw)}, log: log, logCategory: logCategory, infoString: "arrayToComplete after fill0gaps")
        
        if UserDefaults.standard.smoothLibreValues {
            
            // apply Libre smoothing
            LibreSmoothing.smooth(trend: &arrayToComplete, repeatPerMinuteSmoothingSavitzkyGolay: ConstantsLibreSmoothing.libreSmoothingRepeatPerMinuteSmoothing, filterWidthPerMinuteValuesSavitzkyGolay: ConstantsLibreSmoothing.filterWidthPerMinuteValues, filterWidthPer5MinuteValuesSavitzkyGolay: ConstantsLibreSmoothing.filterWidthPer5MinuteValues, repeatPer5MinuteSmoothingSavitzkyGolay: ConstantsLibreSmoothing.repeatPer5MinuteSmoothing)
            
        }
        
        traceGlucoseArray(totrace: arrayToComplete.map{Int($0.glucoseLevelRaw)}, log: log, logCategory: logCategory, infoString: "arrayToComplete after smoothing")

    }
    
    private static func traceGlucoseArray(totrace: [Int], log: OSLog, logCategory: String, infoString: String) {
        
        trace("ARRAY TRACE - %{public}@", log: log, category: logCategory, type: .info, infoString)

        var stringToLog = ""
        
        for element in totrace.prefix(ConstantsLibreSmoothing.amountOfPreviousReadingsToStoreForLibreView) {
            stringToLog = stringToLog + String(format: "%4d", element)
        }
        
        trace("ARRAY TRACE - Full = %{public}@", log: log, category: logCategory, type: .info, stringToLog)

    }
    
    // MARK: - overriden function
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                    
                case UserDefaults.Key.isMaster, UserDefaults.Key.libreViewUrl, UserDefaults.Key.libreViewEnabled, UserDefaults.Key.libreViewPassword, UserDefaults.Key.libreViewUsername :
                    
                    // change by user, should not be done within 200 ms
                    if (keyValueObserverTimeKeeper.verifyKey(forKey: keyPathEnum.rawValue, withMinimumDelayMilliSeconds: 200)) {
                        
                        // TODO
                        
                    }
                    
                default:
                    break
                }
            }
        }
    }

}
