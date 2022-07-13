//
//  RRule.swift
//  RRuleDemoApp
//
//  Created by Justin Honda on 7/5/22.
//

import Foundation

/**
 RFC 5545
 */
public struct RRule {
    
    /// The raw string values listed below are defined in RFC 5545.
    public enum RRuleKey: String, CaseIterable {
        case frequency = "FREQ"
        case interval  = "INTERVAL"
        case byMinute  = "BYMINUTE"
        case byHour    = "BYHOUR"
        case byDay     = "BYDAY"
        case wkst      = "WKST"
    }
    
    // MARK: - Properties
    
    /// REQUIRED pursuant to RFC 5545
    public var frequency: Frequency!
    
    /// Default == 1 pursuant to RFC 5545
    /// MUST be a postive integer
    ///
    /// If value remains 1 at time of RRule string generation, it will be omitted.
    public var interval: Int = 1
    
    /**
     Time input minute component
     
     Using RRule example:
     
     FREQ=DAILY;BYMINUTE=15,30,45;BYHOUR=1,2
     
     The BYMINUTE and BYHOUR are distributive so the above represents
     a total of 6 different times [1:15, 1:30, 1:45, 2:15, 2:30, 2:45].
     
     So a Set type should be sufficient to prevent duplicates and support distributive
     time creation.
     
     Valid input domain: [0, 59]
     */
    public var byMinute: Set<Int> = []
    
    /// Time input hour component
    /// Valid input domain: [0, 23]
    public var byHour: Set<Int> = []
    
    /// Date or Date-Time day component
    public var byDay: Set<Day> = []
    
    /**
     The WKST rule part specifies the day on which the workweek starts.
     Valid values are MO, TU, WE, TH, FR, SA, and SU.  This is
     significant when a WEEKLY "RRULE" has an interval greater than 1,
     and a BYDAY rule part is specified. ...{more to read in RFC 5545}... . The
     default value is MO.
     */
    public var wkst: Day? // TODO: - Still deciding if we want to support this on initial API release
    
    public init() { }
    
    public init(
        frequency: Frequency,
        interval: Int = 1,
        byMinute: Set<Int> = [],
        byHour: Set<Int> = [],
        byDay: Set<Day> = [],
        wkst: Day? = nil
    ) {
        self.frequency = frequency
        self.interval = interval
        self.byMinute = byMinute
        self.byHour = byHour
        self.byDay = byDay
        self.wkst = wkst
    }
    
}

// MARK: - Parsing

extension RRule {
    
    /// Parses an RRule string into a modifiable `RRule` instance
    /// - Parameter rRule: Passed in RRule string (should be in format defined in RFC 5545)
    /// - Returns: A modifiable `RRule` object of the passed in RRule string
    public static func parse(rRule: String) throws -> RRule {
        if rRule.isEmpty { throw RRuleException.emptyRRule }
        
        func map<T>(componentsOf strValue: String, using type: (String) -> T?, forKey key: RRuleKey) throws -> [T] {
            let components = strValue.components(separatedBy: ",")
            let expectedNumberOfValues = components.count
            let mappedValues = components.compactMap { type($0) }
            if mappedValues.count != expectedNumberOfValues {
                throw RRuleException.invalidRRulePart(key, strValue, rRule)
            }
            return mappedValues
        }
        
        let recurrenceRule: RRule = try rRule
            .components(separatedBy: ";")
            .compactMap { kvp -> (RRuleKey, String) in
                let kvpComponents = kvp.components(separatedBy: "=")
                
                guard kvpComponents.count == 2,
                      let keyString = kvpComponents.first,
                      let key = RRuleKey(rawValue: keyString),
                      let value = kvpComponents.last
                else { throw RRuleException.invalidRRuleString(rRule) }
                
                return (key, value)
            }
            .reduce(.init(), { partialRRule, rRuleKeyAndValue in
                let (key, strValue) = (rRuleKeyAndValue.0,
                                       rRuleKeyAndValue.1.trimmingCharacters(in: .whitespacesAndNewlines))
                
                if strValue.isEmpty { throw RRuleException.invalidRRulePart(key, strValue, rRule) }
                
                var _rRule = partialRRule
                switch key {
                    case .frequency:
                        _rRule.frequency = Frequency(rawValue: strValue)
                    case .interval:
                        if let interval = Int(strValue) { _rRule.interval = interval }
                    case .byMinute:
                        _rRule.byMinute = try map(componentsOf: strValue, using: Int.init, forKey: key).asSet()
                    case .byHour:
                        _rRule.byHour = try map(componentsOf: strValue, using: Int.init, forKey: key).asSet()
                    case .byDay:
                        _rRule.byDay = try map(componentsOf: strValue, using: Day.init, forKey: key).asSet()
                    case .wkst:
                        _rRule.wkst = Day(rawValue: strValue)
                }
                return _rRule
            })
        
        guard recurrenceRule.frequency != nil else {
            throw RRuleException.missingFrequency(rRule)
        }
        
        return recurrenceRule
    }
    
}

// MARK: - Generate RRule String

extension RRule {
    
    /// First, all properties on `RRule` are validated to ensure the generated string is correct.
    /// Lastly, all parts, that are present and "should" be added to the RRule string, are added.
    /// - Returns: A correct (pursuant to RFC 5545) RRule string representation of an `RRule`
    /// instance.
    public func asString() throws -> String {
        try validate()
        
        return RRuleKey.allCases.compactMap { key in
            switch key {
                case .frequency:
                    return stringFor(frequency.rawValue, forKey: key)
                case .interval:
                    return stringFor("\(interval)", forKey: key)
                case .byMinute:
                    return stringFor(byMinute.map { "\($0)" }, forKey: key)
                case .byHour:
                    return stringFor(byHour.map { "\($0)" }, forKey: key)
                case .byDay:
                    return stringFor(byDay.map { $0.rawValue }, forKey: key)
                case .wkst:
                    return stringFor(wkst?.rawValue, forKey: key)
            }
        }
        .joined(separator: ";")
    }
    
    private func stringFor<C: Collection>(_ partValue: C?, forKey rRuleKey: RRuleKey) -> String? {
        guard let partValue = partValue, partValue.isEmpty == false else {
            return nil
        }
        
        if rRuleKey == .interval, interval == 1 { return nil }
        
        if let strValue = partValue as? String {
            return [rRuleKey.rawValue, "=", strValue].joined()
        }
        
        if let strValues = partValue as? [String] {
            let joinedPartValues = strValues.joined(separator: ",")
            return [rRuleKey.rawValue, "=", joinedPartValues].joined()
        }
        
        return nil
    }
    
}

// MARK: - Validation

extension RRule {
    
    /// This method validates all properties of an `RRule` instance. If validation(s) failed are found,
    /// this method will throw the appropriate exception providing a useful message for debugging.
    public func validate() throws {
        let failedValidations = RRuleKey.allCases.compactMap { key -> RRuleException.FailedInputValidation? in
            switch key {
                case .frequency:
                    if frequency == nil { return .frequency(nil) }
                case .interval:
                    if let invalidInterval = RRule.validate(interval, for: .interval) {
                        return .interval(invalidInterval)
                    }
                case .byMinute:
                    if let invalidByMinutes = RRule.validate(byMinute, for: .byMinute) {
                        return .byMinute(invalidByMinutes)
                    }
                case .byHour:
                    if let invalidByHours = RRule.validate(byHour, for: .byHour) {
                        return .byHour(invalidByHours)
                    }
                case .byDay: break
                case .wkst: break
            }
            return nil
        }
        
        if failedValidations.count == 1 { throw RRuleException.invalidInput(failedValidations[0]) }
        if failedValidations.count > 1 { throw RRuleException.multiple(failedValidations) }
    }
    
    private typealias IntervalValidator = (Int) -> Bool
    
    private enum TypesRequiringValidation {
        enum Set {
            case byMinute, byHour
            
            var validator: IntervalValidator {
                switch self {
                    case .byMinute: return { $0 >= 0 && $0 <= 59 } // [0,59]
                    case .byHour: return   { $0 >= 0 && $0 <= 23 } // [0,23]
                }
            }
        }
        
        enum Int {
            case interval
            
            var validator: IntervalValidator {
                switch self {
                    case .interval: return { $0 > 0 }
                }
            }
        }
    }
    
    private static func validate(_ values: Set<Int>, for setProperty: TypesRequiringValidation.Set) -> [Int]? {
        let possibleInvalidValues = values.filter { setProperty.validator($0) == false }.compactMap { $0 }
        guard possibleInvalidValues.isEmpty else { return possibleInvalidValues }
        return nil
    }
    
    private static func validate(_ value: Int, for integerProperty: TypesRequiringValidation.Int) -> Int? {
        integerProperty.validator(value) ? nil : value
    }
    
}

// MARK: - RRule Part Types (not all inclusive due to using primitive types for some parts)

public extension RRule {
    
    enum Frequency: String, CaseIterable {
        case daily  = "DAILY"
        case weekly = "WEEKLY"
    }
    
    /// BYDAY (strings)  and WKST (string) use same inputs. For example, in this RRule string:
    /// `FREQ=DAILY;BYDAY=MO,WE,FR;WKST=MO`
    enum Day: String, CaseIterable {
        case sunday    = "SU"
        case monday    = "MO"
        case tuesday   = "TU"
        case wednesday = "WE"
        case thursday  = "TH"
        case friday    = "FR"
        case saturday  = "SA"
        
        static var today: Day {
            let calendar = Calendar.autoupdatingCurrent
            let weekday = calendar.dateComponents([.weekday], from: Date.now).weekday
            switch weekday {
                case 1: return .sunday
                case 2: return .monday
                case 3: return .tuesday
                case 4: return .wednesday
                case 5: return .thursday
                case 6: return .friday
                case 7: return .saturday
                default: return .sunday // See today test in RRuleCalendarTests.swift
            }
        }
    }
    
}

// MARK: - Exception Handling

public extension RRule {
    
    enum RRuleException: Error {
        case missingFrequency(_ message: String)
        case emptyRRule
        case invalidRRuleString(_ rRule: String)
        case invalidRRulePart(_ key: RRuleKey, _ value: String, _ rRule: String)
        case invalidInput(_ failedValidation: FailedInputValidation)
        case multiple(_ failedValidations: [FailedInputValidation])
        case unknownOrUnsupported(rRulePart: String)
        
        public var message: String {
            switch self {
                case .missingFrequency(let rRule):
                    return "⚠️ Pursuant to RFC 5545, FREQ is required. Your RRule -> \(rRule)"
                case .invalidRRuleString(let invalidRRule):
                    return "⚠️ Please check your RRule -> \"\(invalidRRule)\" for correctness."
                case .invalidRRulePart(let key, let value, let invalidRRule):
                    return "⚠️ Invalid value -> \(value) for RRule key -> \(key.rawValue). \(invalidRRule.isEmpty ? "" : "RRule attempted to parse -> \"\(invalidRRule)\"")"
                case .emptyRRule:
                    return "⚠️ Empty RRule string!"
                case .invalidInput(let failedInputValidation):
                    return failedInputValidation.message
                case .multiple(let failedValidations):
                    return """
                ⚠️ Multiple Failed Validations ⚠️
                \(failedValidations.enumerated().map { "\($0 + 1). \($1.message)" }.joined(separator: "\n"))
                """
                case .unknownOrUnsupported(rRulePart: let message):
                    return "⚠️ \(message)"
            }
        }
        
        public enum FailedInputValidation {
            case frequency(Any?)
            case interval(Any)
            case byMinute(Any)
            case byHour(Any)
            case byDay(Any)
            case wkst(Any)
            
            var message: String {
                switch self {
                    case .frequency(let invalidInput):
                        return "⚠️ Invalid \(RRuleKey.frequency.rawValue) input: \(String(describing: invalidInput)) - MUST be one of the following: \(Frequency.allCases.map { $0.rawValue })"
                    case .interval(let invalidInput):
                        return "⚠️ Invalid \(RRuleKey.interval.rawValue) input: \(invalidInput) - MUST be a positive integer."
                    case .byMinute(let invalidInput):
                        return "⚠️ Invalid \(RRuleKey.byMinute.rawValue) input(s): \(invalidInput) - Allowed inputs interval -> [0,59]"
                    case .byHour(let invalidInput):
                        return "⚠️ Invalid \(RRuleKey.byHour.rawValue) input(s): \(invalidInput) - Allowed inputs interval -> [0,23]"
                    case .byDay(let invalidInput):
                        return "⚠️ Invalid \(RRuleKey.byDay.rawValue) input(s): \(invalidInput) - Allowed inputs: \(Day.allCases.map { $0.rawValue })"
                    case .wkst(let invalidInput):
                        return "⚠️ Invalid \(RRuleKey.wkst.rawValue) input: \(invalidInput) - Allowed inputs: \(Day.allCases.map { $0.rawValue })"
                }
            }
        }
    }
    
}

// MARK: - CustomDebugStringConvertible

extension RRule: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        """
        \n\(RRule.self):
        \(debugMessage)
        """
    }
    
    private var debugMessage: String {
        RRuleKey.allCases.map {
            var keyValue = "\($0) ="
            switch $0 {
                case .frequency:
                    keyValue += " \(String(describing: frequency))"
                case .interval:
                    keyValue += " \(interval)"
                case .byMinute:
                    keyValue += " \(byMinute)"
                case .byHour:
                    keyValue += " \(byHour)"
                case .byDay:
                    keyValue += " \(byDay)"
                case .wkst:
                    keyValue += " \(String(describing: wkst))"
            }
            return "\t\(keyValue)"
        }
        .joined(separator: "\n")
    }
    
}

// MARK: - Array where Element: Hashable

private extension Array where Element: Hashable {
    /// Convenient caller to convert an `Array` to a `Set` to avoid less readable
    /// call sites when using a type's initializer
    func asSet() -> Set<Element> { Set(self) }
}

extension RRule.Day: Identifiable {
    public var id: String {
        switch self {
            case .sunday:    return "Sunday"
            case .monday:    return "Monday"
            case .tuesday:   return "Tuesday"
            case .wednesday: return "Wednesday"
            case .thursday:  return "Thursday"
            case .friday:    return "Friday"
            case .saturday:  return "Saturday"
        }
    }
}
