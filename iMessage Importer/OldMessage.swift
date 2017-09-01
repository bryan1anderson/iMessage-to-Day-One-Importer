//
//  OldMessage.swift
//  iMessage Importer
//
//  Created by Bryan on 8/26/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation
import SQLite

struct OldMessage: Equatable, Comparable {
    let id: Int
    let address: String?
    let date: Date
    let text: String?
    let flags: Int
    let groupID: Int
    
    let isFromMe: Bool
    init(row: Row) {
        let ROWID = Expression<Int>("ROWID")
        let address = Expression<String?>("address")
        let date = Expression<Int>("date")
        let text = Expression<String?>("text")
        let flags = Expression<Int>("flags")
        let groupID = Expression<Int>("group_id")
        
        self.id = row[ROWID]
        self.address = row[address]
        
        let flag = row[flags]
        let sent = flag == 3
        self.isFromMe =  sent

        
        let interval = row[date]
        
        let dateTest = Date(timeIntervalSince1970: TimeInterval(interval))
        let cal = Calendar(identifier: Calendar.Identifier.gregorian)
        var components = cal.dateComponents([.day , .month, .year, .hour, .minute ], from: dateTest)
        if let year = components.year, year < 1990 {
            
            let dateSince2001 = Date(timeIntervalSinceReferenceDate: TimeInterval(interval))
            self.date = dateSince2001
        } else {
            self.date = dateTest
        }


        self.text = row[text]
        self.flags = row[flags]
        self.groupID = row[groupID]
    }
    
    static func ==(lhs: OldMessage, rhs: OldMessage) -> Bool {
        return lhs.date == rhs.date &&
            lhs.address == rhs.address &&
            lhs.text == rhs.text
    }
    
    static func <(lhs: OldMessage, rhs: OldMessage) -> Bool {
        return lhs.date < rhs.date
    }
    
    func dateString() -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        let dateString = dateFormatter.string(from: date)
        return dateString
    }

}

struct Member: Comparable, Equatable {
    let id: Int
    let groupID: Int
    let address: String?
    
    init(row: Row) {
        let ROWID = Expression<Int>("ROWID")
        let address = Expression<String?>("address")
        let groupID = Expression<Int>("group_id")
        
        self.id = row[ROWID]
        self.address = row[address]?.cleaned
        self.groupID = row[groupID]
    }
    
    static func ==(lhs: Member, rhs: Member) -> Bool {
        return lhs.address == rhs.address
    }
    
    static func <(lhs: Member, rhs: Member) -> Bool {
        guard let lhsAddress = lhs.address,
            let rhsAddress = rhs.address else { return false }
        return lhsAddress < rhsAddress
    }
    
}

struct Group {
    let id: Int
    let type: Int
    
    init(row: Row) {
        let ROWID = Expression<Int>("ROWID")
        let typeColumn = Expression<Int>("type")
        
        self.id = row[ROWID]
        self.type = row[typeColumn]
    }
}

