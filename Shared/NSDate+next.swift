
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

extension NSDate {
    func nextHour() -> NSDate? {
        let components = NSDateComponents()
        components.minute = 0
        return NSCalendar.currentCalendar().nextDateAfterDate(self, matchingComponents: components, options: [.MatchNextTime, .MatchStrictly])
    }
    func nextDayAt(hour: Int, minute: Int) -> NSDate? {
        let components = NSDateComponents()
        components.hour = hour
        components.minute = minute
        return NSCalendar.currentCalendar().nextDateAfterDate(self, matchingComponents: components, options: [.MatchNextTime, .MatchStrictly])
    }
    func nextWeekAt(hour: Int, minute: Int) -> NSDate? {
        let components = NSDateComponents()
        components.weekday = 1
        components.hour = hour
        components.minute = minute
        return NSCalendar.currentCalendar().nextDateAfterDate(self, matchingComponents: components, options: [.MatchNextTime, .MatchStrictly])
    }
    func nextMonthAt(hour: Int, minute: Int) -> NSDate? {
        let componentMask : NSCalendarUnit = [.Year, .Month, .Day, .Hour, .Minute]
        let components = NSCalendar.currentCalendar().components(componentMask, fromDate: self)
        components.month += 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        components.second = 0
        return NSCalendar.currentCalendar().dateFromComponents(components)
    }
}