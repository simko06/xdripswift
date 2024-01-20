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
            
            followGlucoseDataArray.append(GlucoseData(timeStamp: Date(timeIntervalSince1970: date/1000), glucoseLevelRaw: sgv))
            
        }

        self.loopFollowerDelegate?.loopFollowerInfoReceived(followGlucoseDataArray: &followGlucoseDataArray)

    }
        

    // MARK: - overriden function
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                    
                case UserDefaults.Key.isMaster :
                    
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
