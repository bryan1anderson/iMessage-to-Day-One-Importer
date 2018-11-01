//
//  Attachment.swift
//  iMessage Importer
//
//  Created by Bryan on 12/12/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation
import SQLite

struct Attachment {
    let id: Int
    let date: Date
    let filename: String
//    let uti: String
    private let mimeTypeRaw: String
//    let isOutGoing: Bool
//    let transferName: String
//    let totalBytes: Int
    let mimeType: MimeType
    let guid: String
//    let originalGuid: String
    
    init?(row: Row) {
        let rowidColumn = Expression<Int>("ROWID")
        
        let guidColumn = Expression<String>("guid")
        let filenameColumn = Expression<String?>("filename")
        let mimeTypeColumn = Expression<String?>("mime_type")
        let dateColumn = Expression<Int>("created_date")
        
        self.id = row[rowidColumn]
        self.guid = row[guidColumn]
        
        guard let filename = row[filenameColumn] else { return nil }
        self.filename = filename
        
        guard let mimeTypeRaw = row[mimeTypeColumn] else { return nil }
        self.mimeTypeRaw = mimeTypeRaw
        
        let mimeType = MimeType(mimeTypeRaw)
        self.mimeType = mimeType
        
        var interval = Double(row[dateColumn]) / 1000000000
        if interval < 1000 {
            interval = Double(row[dateColumn])
        }
        let messageDate = Date(timeIntervalSinceReferenceDate: interval)
        self.date = messageDate
        
    }
}
