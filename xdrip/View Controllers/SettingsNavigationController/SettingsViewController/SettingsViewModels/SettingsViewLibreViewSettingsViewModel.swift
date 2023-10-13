import UIKit
import os
import Foundation

fileprivate enum Setting:Int, CaseIterable {
    
    ///should readings be uploaded or not
    case libreViewEnabled = 0
    
    ///nightscout url
    case libreViewUrl = 1
    
    /// libreview username
    case libreViewUsername = 2
    
    /// nightscout api key
    case libreViewPassword = 3
    
    /// to allow testing explicitly
    case testUrlAndAPIKey = 4
    
}

class SettingsViewLibreViewSettingsViewModel {
    
    // MARK: - properties
    
    /// in case info message or errors occur like credential check error, then this closure will be called with title and message
    /// - parameters:
    ///     - first parameter is title
    ///     - second parameter is the message
    ///
    /// the viewcontroller sets it by calling storeMessageHandler
    private var messageHandler: ((String, String) -> Void)?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categorySettingsViewLibreViewSettingsViewModel)
    
    // MARK: - private functions
    
    /// test the nightscout url and api key and send result to messageHandler
    private func testLibreViewCredentials() {

        guard let username = UserDefaults.standard.libreViewUsername, let password = UserDefaults.standard.libreViewPassword, let siteUrl = UserDefaults.standard.libreViewUrl else {return}

        LibreViewFollowManager.loginToLibreView(username: username, password: password, siteUrl: siteUrl, log: self.log, logCategory: ConstantsLog.categoryLibreViewFollowManager, completion: { (errorText: String?, token: String?) in
            
            if token != nil {
                self.callMessageHandlerInMainThread(title: TextsNightScout.verificationSuccessfulAlertTitle, message: "LibreView credentials were verified successfully.")
            } else {
                var fullErrorText = "LibreView credentials check failed. "
                if let errorText = errorText {
                    fullErrorText = fullErrorText + "Error = " + errorText
                }
                self.callMessageHandlerInMainThread(title: TextsNightScout.verificationErrorAlertTitle, message: "fullErrorText")
            }
            
            // assign token to UserDefaults.standard.libreViewToken
            // possible value is nil here, which means login failed so we set the token in UserDefaults to nil
            UserDefaults.standard.libreViewToken = token
            
        })
        
    }
    
    private func callMessageHandlerInMainThread(title: String, message: String) {
        
        // unwrap messageHandler
        guard let messageHandler = messageHandler else {return}
        
        DispatchQueue.main.async {
            messageHandler(title, message)
        }
        
    }
    
}

/// conforms to SettingsViewModelProtocol for all nightscout settings in the first sections screen
extension SettingsViewLibreViewSettingsViewModel: SettingsViewModelProtocol {
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}

    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {
        self.messageHandler = messageHandler
    }
    
   func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return !UserDefaults.standard.isMaster
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .libreViewEnabled:
            return SettingsSelectedRowAction.nothing
            
        case .libreViewUrl:
            return SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelNightScoutUrl, message: "Enter your Libreview URL", keyboardType: .URL, text: UserDefaults.standard.libreViewUrl != nil ? UserDefaults.standard.libreViewUrl : ConstantsLibreView.defaultLibreViewUrl, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(nightscouturl:String) in
                
                // url changed, set token  to nil, new test is needed
                UserDefaults.standard.libreViewToken = nil
                
                // if user gave empty string then set to nil
                // if not nil, and if not starting with http or https, add https, and remove ending /
                var enteredURL = nightscouturl.toNilIfLength0()
                
                // assuming that the enteredURL isn't nil, isn't the default value and hasn't been entered without a valid scheme
                if enteredURL != nil && !enteredURL!.startsWith("https://http") {
                    
                    // if self doesn't start with http or https, then add https. This might not make sense, but it will guard against throwing fatal errors when trying to get the scheme of the Endpoint
                    if !enteredURL!.startsWith("http://") && !enteredURL!.startsWith("https://") {
                        enteredURL = "https://" + enteredURL!
                    }
                    
                    // if url ends with /, remove it
                    if enteredURL!.last == "/" {
                        enteredURL!.removeLast()
                    }
                    
                    // remove the login path if it exists
                    enteredURL = enteredURL!.replacingOccurrences(of: ConstantsLibreView.libreViewLoginPath, with: "")
                    
                    // if we've got a valid URL, then let's break it down
                    if let enteredURLComponents = URLComponents(string: enteredURL!) {
                        
                        // finally, let's make a clean URL with just the scheme and host. We don't need to add anything else as this is basically the only thing we were asking for in the first place.
                        var nighscoutURLComponents = URLComponents()
                        nighscoutURLComponents.scheme = "https"
                        nighscoutURLComponents.host = enteredURLComponents.host?.lowercased()
                        
                        UserDefaults.standard.libreViewUrl = nighscoutURLComponents.string!
                        
                    }
                    
                } else {
                    
                    // there must be something wrong with the URL the user is trying to add, so let's just ignore it
                    UserDefaults.standard.libreViewUrl = nil
                    
                }
                
            }, cancelHandler: nil, inputValidator: nil)

        case .libreViewPassword:
            return SettingsSelectedRowAction.askText(title: "Password", message:  "Give Password", keyboardType: .default, text: UserDefaults.standard.libreViewPassword, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(password:String) in
                
                // password changed, set token  to nil, new test is needed
                UserDefaults.standard.libreViewToken = nil

                UserDefaults.standard.libreViewPassword = password.toNilIfLength0()
                
            }, cancelHandler: nil, inputValidator: nil)

        case .testUrlAndAPIKey:

                self.testLibreViewCredentials()
                
                return .nothing

        case .libreViewUsername:
            return SettingsSelectedRowAction.askText(title: "Username", message:  "Give Username", keyboardType: .default, text: UserDefaults.standard.libreViewUsername, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: {(username:String) in
            
                // password changed, set token  to nil, new test is needed
                UserDefaults.standard.libreViewToken = nil

                UserDefaults.standard.libreViewUsername = username.toNilIfLength0()
                
            }, cancelHandler: nil, inputValidator: nil)

        }
    }
    
    func sectionTitle() -> String? {
        return "LibreView"
    }

    func numberOfRows() -> Int {
        
        // if nightscout upload not enabled then only first row is shown
        if UserDefaults.standard.libreViewEnabled {
            
            // in master mode, enabling is not possible
            if UserDefaults.standard.isMaster {
                return 1
            }
            
            return Setting.allCases.count
            
        } else {
            return 1
        }
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .libreViewEnabled:
            return UserDefaults.standard.isMaster ? "Only in follower mode" : "Enable LibreView?"
        case .libreViewUrl:
            return "url"
        case .libreViewPassword:
            return "password"
        case .testUrlAndAPIKey:
            return "Test Connection?"
        case .libreViewUsername:
            return "username"
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .libreViewEnabled:
            return UITableViewCell.AccessoryType.none
        case .libreViewUrl:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .libreViewPassword:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .testUrlAndAPIKey:
            return .none
        case .libreViewUsername:
            return UITableViewCell.AccessoryType.disclosureIndicator
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .libreViewEnabled:
            return nil
        case .libreViewUrl:
            return UserDefaults.standard.libreViewUrl
        case .libreViewPassword:
            return UserDefaults.standard.libreViewPassword != nil ? obscureString(stringToObscure: UserDefaults.standard.libreViewPassword) : nil
        case .testUrlAndAPIKey:
            return UserDefaults.standard.libreViewToken != nil ? "Test Ok":"Not tested"
        case .libreViewUsername:
            return UserDefaults.standard.libreViewUsername
        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .libreViewEnabled:
            return UISwitch(isOn: UserDefaults.standard.libreViewEnabled, action: {(isOn:Bool) in UserDefaults.standard.libreViewEnabled = isOn})
        
        case .libreViewUrl:
            return nil
            
        case .libreViewPassword:
            return nil
            
        case .testUrlAndAPIKey:
            return nil
            
        case .libreViewUsername:
            return nil
            
        }
    }
    
    func obscureString(stringToObscure: String?) -> String {
        
        // make sure that something useful has been passed to the function
        guard var obscuredString = stringToObscure else { return "" }
        
        let stringLength: Int = obscuredString.count
        
        // in order to avoid strange layouts if somebody uses a really long API_SECRET, then let's limit the displayed string size to something more manageable
        let maxStringSizeToShow: Int = 12
        
        // the characters we will use to obscure the sensitive data
        let maskingCharacter: String = "*"
        
        // based upon the length of the string, we will show more, or less, of the original characters at the beginning. This gives more context whilst maintaining privacy
        var startCharsNotToObscure: Int = 0
        
        switch stringLength {
        case 0...3:
            startCharsNotToObscure = 0
        case 4...5:
            startCharsNotToObscure = 1
        case 6...7:
            startCharsNotToObscure = 2
        case 8...10:
            startCharsNotToObscure = 3
        case 11...50:
            startCharsNotToObscure = 4
        default:
            startCharsNotToObscure = 0
        }
        
        // remove the characters that we want to obscure
        obscuredString.removeLast(stringLength - startCharsNotToObscure)
        
        // now "fill up" the string with the masking character up to the original string size. If it is longer than the maxStingSizeToShow then trim it down to make everything fit in a clean way
        obscuredString += String(repeating: maskingCharacter, count: stringLength > maxStringSizeToShow ? maxStringSizeToShow - obscuredString.count : stringLength - obscuredString.count)
        
        return obscuredString
        
    }
    
}


