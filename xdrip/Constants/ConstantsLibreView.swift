import Foundation

enum ConstantsLibreView {
    
    /// - default libreview url
    /// - used in settings, when setting first time libreview  url
    static let defaultLibreViewUrl = "https://api-eu.libreview.io"
    
    /// path to login
    static let libreViewLoginPath = "/llu/auth/login"
    
    /// path to get connections, used to get patientId
    static let libreViewConnectionPath = "/llu/connections"
 
    /// factoryTimestamp  format in a reading downloaded from LibreView
    static let libreViewFactoryTimeStampDateFormat = "M/d/yyyy h:mm:ss a"
    
    /// factoryTimestamp  timezone in a reading downloaded from LibreView
    static let libreViewFactoryTimeStampTimeZone = "GMT"
    
}
