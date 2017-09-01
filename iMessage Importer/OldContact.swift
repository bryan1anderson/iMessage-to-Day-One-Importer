//
//  OldContact.swift
//  iMessage Importer
//
//  Created by Bryan on 8/26/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation
import SQLite

struct OldContact {
    let first: String?
    let last: String?
    let middle: String?
    
    let recordID: Int
    let values: [String]
    
    init?(row: Row, values: [String]) {
        let firstColumn = Expression<String?>("First")
        let lastColumn = Expression<String?>("Last")
        let middleColumn = Expression<String?>("Middle")
        //        let recordIDColumn = Expression<Int?>("record_id")
        let rowIDColumn = Expression<Int?>("ROWID")
        guard let first = row[firstColumn] else { return nil }
        self.first = first
            
        guard let last = row[lastColumn] else { return nil }
        self.last = last
                
        self.middle = row[middleColumn]
        
        guard let recordID = row[rowIDColumn] else {
            return nil }
        self.recordID = recordID
        
        
        self.values = values.flatMap({ $0.cleaned }).removeDuplicates()
    }
}
