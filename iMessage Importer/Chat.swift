//
//  Chat.swift
//  iMessage Importer
//
//  Created by Bryan on 8/8/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation
import SQLite
import Contacts

struct Chat {
    
    let displayName: String?
    let id: Int
    
    init(row: Row) {
        let displayNameColumn = Expression<String?>("display_name")
        let rowIDColumn = Expression<Int>("ROWID")
        
        self.id = row[rowIDColumn]
        self.displayName = row[displayNameColumn]

    }
}

struct Handle: Equatable {
    let id: Int
    let value: String?
    
    init(row: Row) {
        let idColumn = Expression<String?>("id")
        let rowIDColumn = Expression<Int>("ROWID")
        
        
        self.id = row[rowIDColumn]
        self.value = row[idColumn]
        
    }
    
    static func ==(lhs: Handle, rhs: Handle) -> Bool {
        return rhs.id == lhs.id
    }
}

struct Contact: Equatable {
    let handle: Handle
    let contacts: [CNContact]
    
    init(handle: Handle, contacts: [CNContact]) {
        self.handle = handle
        self.contacts = contacts
    }
    
    static func ==(lhs: Contact, rhs: Contact) -> Bool {
        return rhs.handle.id == lhs.handle.id
    }
}
