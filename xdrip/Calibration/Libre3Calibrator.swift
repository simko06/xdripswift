import Foundation

/// same as Libre1Calibrator but rawValueDivider = 1.0. 
class LibreViewCalibrator: Calibrator {
    
    var rawValueDivider: Double = 1.0
    
    let sParams: SlopeParameters = SlopeParameters(LOW_SLOPE_1: 1, LOW_SLOPE_2: 1, HIGH_SLOPE_1: 1, HIGH_SLOPE_2: 1, DEFAULT_LOW_SLOPE_LOW: 1, DEFAULT_LOW_SLOPE_HIGH: 1, DEFAULT_SLOPE: 1, DEFAULT_HIGH_SLOPE_HIGH: 1, DEFAUL_HIGH_SLOPE_LOW: 1)
    
    let ageAdjustMentNeeded: Bool = false
    
    func description() -> String {
        return "LibreViewCalibrator"
    }

}
