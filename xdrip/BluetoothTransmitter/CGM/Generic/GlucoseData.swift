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
     Inserts this GlucoseData chronologically into the array 'into'. First element in the array "into' is the first
     */
    func insertChronologically(into:inout [GlucoseData]) {
        
        // insert entry chronologically sorted, first is the youngest
        if into.count == 0 {
            into.append(self)
        } else {
            var elementInserted = false
            loop : for (index, element) in into.enumerated() {
                if element.timeStamp < self.timeStamp {
                    into.insert(self, at: index)
                    elementInserted = true
                    break loop
                }
            }
            if !elementInserted {
                into.append(self)
            }
        }
    }
    
}

