import Foundation

extension DateFormatter {
    
    /**
     creates a dateformatter with dateformat defined buy parameter dateFormat
     */
    static func getDateFormatter(dateFormat: String) -> DateFormatter {

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        
        return dateFormatter
        
    }
    
}
