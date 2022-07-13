import Foundation

public class RRuleFormatter: Formatter {
        
    public override func string(for obj: Any?) -> String? {
        guard let rRule = obj as? RRule, let frequency = rRule.frequency else {
            return nil
        }
        
        switch frequency {
            case .daily:
                if rRule.byHour.isEmpty {
                    // get current time
                    
                }
                break
            case .weekly:
                break
        }
        
        return nil
    }
    
    public override func getObjectValue(
        _ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
        for string: String,
        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) -> Bool {
        true
    }
    
    /// Examples:
    /// DAILY
    /// 1. 8:05 AM Every 2 days (interval > 1)
    /// 2. 8:05 AM Every day (interval == 1)
    ///
    /// WEEKLY
    /// 1. 8:05 AM Tue (interval == 1)
    /// 2. 8:05 AM Tue,Thu, Fri (interval == 1)
    /// 2. 8:05 AM Every 2 weeks on Sun, Tue, Fri (interval > 1)
    ///
    /// - Parameter rRule: TBD
    /// - Returns: TBD
    public func string(from rRule: RRule) -> String {
        // NOTE: - We should always have a time so if the RRule
        // passed in does not have one, what should we do? Take
        // the current time and add it to the string?
        guard let frequency = rRule.frequency else { return "" }
        switch frequency {
            case .daily:
                // Assume we have time info
                // Hour will be in 24-hour format therefore
                // any valid hour integer >= 12 will be PM.
                // So substract any PM integer > 12 by 12 to get
                // the corresponding 12-hour system hour. i.e. 16 - 12
                // is equal to 4 PM
                
                return "8 AM \(Interval.everyDay(rRule.interval).description)"
            case .weekly:
                let daysJoined = rRule.byDay.sorted().map { $0.id.prefix(3) }.joined(separator: ", ")
                return "8 AM \(Interval.everyWeek(rRule.interval).description) \(daysJoined)"
        }
    }
    
}

extension RRuleFormatter {
    enum Interval {
        case everyDay(Int)
        case everyWeek(Int)
        
        var description: String {
            switch self {
                case .everyDay(let interval):
                    if interval == 1 {
                        return "Every day"
                    } else {
                        return "Every \(interval) days"
                    }
                case .everyWeek(let interval):
                    if interval == 1 {
                        return ""
                    } else {
                        return "Every \(interval) weeks on"
                    }
            }
        }
    }

}

extension RRule.Day: Comparable {
    
    public static func < (lhs: RRule.Day, rhs: RRule.Day) -> Bool {
        lhs.ordinal < rhs.ordinal
    }
    
    var ordinal: Int {
        switch self {
            case .sunday:    return 1
            case .monday:    return 2
            case .tuesday:   return 3
            case .wednesday: return 4
            case .thursday:  return 5
            case .friday:    return 6
            case .saturday:  return 7
        }
    }
    
}
