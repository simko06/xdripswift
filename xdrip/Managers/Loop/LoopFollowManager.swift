import Foundation
import os
import AVFoundation

class LoopFollowManager: NSObject {
    
    // MARK: - private properties
    
    /// to solve problem that sometemes UserDefaults key value changes is triggered twice for just one change
    private let keyValueObserverTimeKeeper:KeyValueObserverTimeKeeper = KeyValueObserverTimeKeeper()
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLoopFollowManager)
    
    /// reference to coredatamanager
    private var coreDataManager:CoreDataManager
    
    /// reference to BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor
    
    /// delegate to pass back glucosedata
    private (set) weak var loopFollowerDelegate:LoopFollowerDelegate?
    
    /// dateformatter for factoryTimetamp in readings downloaded form LibreView
    private static let libreViewDateFormatter = {
        var dateFormatter = DateFormatter.getDateFormatter(dateFormat: ConstantsLibreView.libreViewFactoryTimeStampDateFormat)
        dateFormatter.timeZone = TimeZone(identifier: ConstantsLibreView.libreViewFactoryTimeStampTimeZone)
        return dateFormatter
    }()
    
    
    // MARK: - initializer
        
    /// initializer
    public init(coreDataManager: CoreDataManager, loopFollowerDelegate: LoopFollowerDelegate) {
        
        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.loopFollowerDelegate  = loopFollowerDelegate
        
        // call super.init
        super.init()
        
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.isMaster.rawValue, options: .new, context: nil)
        
    }
    
    // MARK: - public functions
    
    /// get reading from shared user defaults
    public func getReading() {
        
        // check that app is in follower mode
        guard !UserDefaults.standard.isMaster else {return}
        
        guard let sharedUserDefaults = UserDefaults(suiteName: Bundle.main.appGroupSuiteName) else {return}
        
        guard let encodedLatestReadings = sharedUserDefaults.data(forKey: "latestReadingsFromLoop") else {return}

        let decodedLatestReadings = try? JSONSerialization.jsonObject(with: encodedLatestReadings, options: [])
        
        guard let latestReadings = decodedLatestReadings as? Array<AnyObject> else {return}
        
        var followGlucoseDataArray = [GlucoseData]()
        
        for reading in latestReadings {
            
            guard let date = reading["date"] as? Double, let sgv = reading["sgv"] as? Double else {return}
            
            followGlucoseDataArray.append(GlucoseData(timeStamp: Date(timeIntervalSince1970: date), glucoseLevelRaw: sgv))
            
        }

        // call libreLinkFollowerInfoReceived in main thread
        DispatchQueue.main.sync {

            self.loopFollowerDelegate?.loopFollowerInfoReceived(followGlucoseDataArray: &followGlucoseDataArray)

        }
        
    }
        

    // MARK: - private functions
    
    /// - Make sure glucose data array has at least amountOfPreviousReadingsToStoreForLibreView of per minutes readings, if necessary fill up with values download during previous session, or by using interpolation
    /// - Also apply smoothing
    private static func completeAndSmoothGlucoseData(arrayToComplete: inout [GlucoseData], log: OSLog, logCategory: String) {

        // if prevoiusRawGlucoseValues is empty, then intialize this first
        var previousRawGlucoseValues: [Int] = UserDefaults.standard.previousRawGlucoseValues ?? [Int]()
        let previousRawGlucoseValueTimeStampAsInt: Int64 = UserDefaults.standard.previousRawGlucoseValueTimeStamp?.toSecondsAsInt64() ?? 0

        // variable to iterate through arrayToComplete, just as long as we don't hit the end
        // we will not use the first element in the array (ie with index 0), because we know that's the latest one, so start with index 1
        var arrayToCompleteIndex = 1
        
        // iterate through all elements in arrayToCompleteIndex
        // as we find 'gaps' (ie minutes for which there's no readings), create a new instance of GlucoseData with glucose value 0
        loop1: while arrayToCompleteIndex <= arrayToComplete.count - 1 {
            
            // starting from arrayToComplete[arrayToCompleteIndex - 1] (ie the previous element)
            // take the timestamp of that element and subtract 60 seconds
            // then compare with the timestamp of arrayToComplete[arrayToCompleteIndex], difference should be max 5 seconds (5 seconds because Libre readings tend to come with a few (normally only 1) seconds difference)
            
            // timestamp of the previous element in arrayToComplete, to which we compare the timestamp
            let timeStampOfElementToWhichComparisonIsDoneAsInt = arrayToComplete[arrayToCompleteIndex - 1].timeStamp.toSecondsAsInt64()

            if abs(arrayToComplete[arrayToCompleteIndex].timeStamp.toSecondsAsInt64() - (timeStampOfElementToWhichComparisonIsDoneAsInt - 60)) > 30 {
                
                // the element at arrayToCompleteIndex is more than 1 minute earlier than the previous one
                // here we need to insert an instance of GlucoseData with value 0
                
                arrayToComplete.insert(GlucoseData(timeStamp: Date(timeIntervalSince1970: Double(timeStampOfElementToWhichComparisonIsDoneAsInt) - 60.0), glucoseLevelRaw: 0.0), at: arrayToCompleteIndex)

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
        
        // start the process
        if let first = arrayToComplete.first {

            // two variables needed in that process:
            let timeDifference = first.timeStamp.toSecondsAsInt64() - previousRawGlucoseValueTimeStampAsInt
            let indexDifference = Int(round(Double(timeDifference)/Double(60)))
            var index = 0

            // first replace 0 values in previousRawGlucoseValues with values found in arrayToComplete
            
            // the element at index in previousRawGlucoseValues corresponds (in time) to the value at indexDifference in arrayToComplete
            while index < previousRawGlucoseValues.count && index + indexDifference < arrayToComplete.count {
                if previousRawGlucoseValues[index] == 0 {
                    previousRawGlucoseValues[index] = Int(arrayToComplete[index + indexDifference].glucoseLevelRaw)
                }
                index += 1
            }
            
            // previousRawGlucoseValues may be shorter than amountOfPreviousReadingsToStoreForLibreView
            // append missing values, to come to an amount amountOfPreviousReadingsToStoreForLibreView - indexDifference, because we'll prepend the first missing values later
            // (why '- indexDifference' because we'll also prepend values at the beginning, amount indexDifference
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

            // now do the opposite, replace 0 values in arrayToComplete with values from previousRawGlucoseValues
            
            index = 0
            
            // now the first element in previousRawGlucoseValues corresponds to the first element in arrayToComplete (qua timing)
            while index < previousRawGlucoseValues.count && index < arrayToComplete.count {
                
                if arrayToComplete[index].glucoseLevelRaw == 0.0 {
                    
                    arrayToComplete[index].glucoseLevelRaw = Double(previousRawGlucoseValues[index])
                    
                }
                
                index += 1
                
            }

        }

        // fill up gaps, ie entries where rawvalue = 0, using interpolation
        arrayToComplete.fill0Gaps(maxGapWidth: 30)

        // apply smoothing
        if UserDefaults.standard.smoothLibreValues {
            
            // apply Libre smoothing
            LibreSmoothing.smooth(trend: &arrayToComplete, repeatPerMinuteSmoothingSavitzkyGolay: ConstantsLibreSmoothing.libreSmoothingRepeatPerMinuteSmoothing, filterWidthPerMinuteValuesSavitzkyGolay: ConstantsLibreSmoothing.filterWidthPerMinuteValues, filterWidthPer5MinuteValuesSavitzkyGolay: ConstantsLibreSmoothing.filterWidthPer5MinuteValues, repeatPer5MinuteSmoothingSavitzkyGolay: ConstantsLibreSmoothing.repeatPer5MinuteSmoothing)
            
        }
        
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
