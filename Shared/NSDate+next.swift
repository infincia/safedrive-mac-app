
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

extension Date {
    func nextHour() -> Date? {
        var components = DateComponents()
        components.minute = 0
        return (Calendar.current as NSCalendar).nextDate(after: self, matching: components, options: [.matchNextTime, .matchStrictly])
    }
    func nextDayAt(_ hour: Int, minute: Int) -> Date? {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return (Calendar.current as NSCalendar).nextDate(after: self, matching: components, options: [.matchNextTime, .matchStrictly])
    }
    func nextWeekAt(_ hour: Int, minute: Int) -> Date? {
        var components = DateComponents()
        components.weekday = 1
        components.hour = hour
        components.minute = minute
        return (Calendar.current as NSCalendar).nextDate(after: self, matching: components, options: [.matchNextTime, .matchStrictly])
    }
    func nextMonthAt(_ hour: Int, minute: Int) -> Date? {
        let componentMask: NSCalendar.Unit = [.year, .month, .day, .hour, .minute]
        var components = (Calendar.current as NSCalendar).components(componentMask, from: self)
        if var month = components.month {
            month  += 1
            components.month = month
        }
        components.day = 1
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components)
    }
}
