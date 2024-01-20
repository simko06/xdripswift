import Foundation

/// glucose,
public class GlucoseData {
    
    var timeStamp:Date

    var glucoseLevelRaw:Double

    /// used when needed
    var slopeOrdinal: Int?
    
    /// used when needed
    var slopeName: String?
    
    init(timeStamp:Date, glucoseLevelRaw:Double) {
        
        self.timeStamp = timeStamp
        
        self.glucoseLevelRaw = glucoseLevelRaw
        
    }
    
    init(timeStamp:Date, glucoseLevelRaw:Double, slopeOrdinal: Int, slopeName: String) {
        
        self.timeStamp = timeStamp
        
        self.glucoseLevelRaw = glucoseLevelRaw
        
        self.slopeOrdinal = slopeOrdinal
        
        self.slopeName = slopeName
        
    }

    /**
     initializer taking timeStamp as string, dateFormatter defines the formatter to parse the string, sgv is the value in mg/dl
     */
    convenience init?(timeStamp:String, sgv: Int, dateFormatter: DateFormatter) {
        
        if let date = dateFormatter.date(from: timeStamp) {
            
            self.init(timeStamp: date, glucoseLevelRaw: Double(sgv))
            
        } else {
            
            return nil
            
        }
        
    }

    var description: String {
        
        return "timeStamp = " + timeStamp.description(with: .current) + ", glucoseLevelRaw = " + glucoseLevelRaw.description
        
    }
    
    /**
     Inserts this GlucoseData chronologically into the array 'into'. First element in the array "into' is the first. Assumes that the array into is already in the correct order before inserting
     */
    func insertChronologically(into:inout [GlucoseData]) {

        // if there's no last element, then the array is empty and we just need to append
        guard let last = into.last else {
            into.append(self)
            return
        }
        
        var elementInserted = false

        // since into is already chronologically sorted, and the chance is high that the new element needs to be inserted either in the beginning orin the end, let's start by end, in next step will start at the beginning and then continue one by one
        if self.timeStamp >= last.timeStamp {
            into.append(self)
        }
        
        if !elementInserted {
            loop : for (index, element) in into.enumerated() {
                if element.timeStamp <= self.timeStamp {
                    into.insert(self, at: index)
                    elementInserted = true
                    break loop
                }
            }
        }
        
        if !elementInserted {
            // should probably never occur
            into.append(self)
        }

    }
    
}
