
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

extension NSDate {
    func nextHour() -> NSDate? {
        let components = NSDateComponents()
        components.minute = 0
        return NSCalendar.currentCalendar().nextDateAfterDate(self, matchingComponents: components, options: [.MatchNextTime, .MatchStrictly])
    }
    func nextDay() -> NSDate? {
        let components = NSDateComponents()
        components.hour = 0
        return NSCalendar.currentCalendar().nextDateAfterDate(self, matchingComponents: components, options: [.MatchNextTime, .MatchStrictly])
    }
    func nextWeek() -> NSDate? {
        let components = NSDateComponents()
        components.weekday = 1
        return NSCalendar.currentCalendar().nextDateAfterDate(self, matchingComponents: components, options: [.MatchNextTime, .MatchStrictly])
    }
    func nextMonth() -> NSDate? {
        let componentMask : NSCalendarUnit = [.Year, .Month, .Day, .Hour, .Minute]
        let components = NSCalendar.currentCalendar().components(componentMask, fromDate: self)
        components.month += 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        return NSCalendar.currentCalendar().dateFromComponents(components)
    }
}