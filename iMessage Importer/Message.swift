//
//  Message.swift
//  iMessage Importer
//
//  Created by Bryan on 8/8/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation
import SQLite

enum MessageType: String {
    case text
    case iMessage
    case failed
}

extension String {
    
    var cleaned: String {
        let cleaned = self.replacingOccurrences(of: "[ |+()-]", with: "", options: [.regularExpression])
        return cleaned
    }
}

class Message: Equatable, Comparable {
    
    let id: Int
    let isFromMe: Bool
    let handleID: Int
    let text: String?
    let date: Date
    var attachments: [Attachment]?
    
    init(row: Row) {
        let rowidColumn = Expression<Int>("ROWID")

        let isFromMeColumn = Expression<Bool>("is_from_me")
        let handleIDColumn = Expression<Int>("handle_id")
        let textColumn = Expression<String?>("text")
        let dateColumn = Expression<Int>("date")
        
        self.id = row[rowidColumn]
        self.isFromMe = row[isFromMeColumn]
        self.handleID = row[handleIDColumn]
        self.text = row[textColumn]
    
        var interval = Double(row[dateColumn]) / 1000000000
        if interval < 1000 {
            interval = Double(row[dateColumn])
        }
        let messageDate = Date(timeIntervalSinceReferenceDate: interval)
        self.date = messageDate

    }
    
    static func ==(lhs: Message, rhs: Message) -> Bool {
        return lhs.text == rhs.text &&
            lhs.date == rhs.date
    }

    static func <(lhs: Message, rhs: Message) -> Bool {
        return lhs.date < rhs.date
    }
    
    func dateString() -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        let dateString = dateFormatter.string(from: date)
        return dateString
    }
}


extension NSImage: Value {
    public class var declaredDatatype: String {
        return Blob.declaredDatatype
    }
    public class func fromDatatypeValue(_ blobValue: Blob) -> NSImage {
        return NSImage(data: Data.fromDatatypeValue(blobValue))!
    }
    public var datatypeValue: Blob {
        return self.datatypeValue
        
        return self.tiffRepresentation!.datatypeValue
    }
    
}

