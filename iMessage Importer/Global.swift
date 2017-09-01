//
//  Global.swift
//  iMessage Importer
//
//  Created by Bryan on 8/8/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation

//extension String {
//    
//    var cleaned: String {
//        let cleaned = self.replacingOccurrences(of: "[ |+()-]", with: "", options: [.regularExpression])
//        return cleaned
//    }
//}

extension Array where Element:Equatable {
    func removeDuplicates() -> [Element] {
        var result = [Element]()
        
        for value in self {
            if result.contains(value) == false {
                result.append(value)
            }
        }
        
        return result
    }
}

extension Date {
    var yesterday: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: self)!
    }
    var tomorrow: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: self)!
    }
    var noon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }
    var midnight: Date {
        return Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: self)!
    }
    
    var yesterdayMidnight: Date {
        return Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: self.yesterday)!
    }

    var month: Int {
        return Calendar.current.component(.month,  from: self)
    }
    var isLastDayOfMonth: Bool {
        return tomorrow.month != month
    }
}
