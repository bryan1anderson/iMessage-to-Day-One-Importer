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

struct Chat: Equatable {
    
    let displayName: String?
    let id: Int
    
    init(row: Row) {
        let displayNameColumn = Expression<String?>("display_name")
        let rowIDColumn = Expression<Int>("ROWID")
        
        self.id = row[rowIDColumn]
        self.displayName = row[displayNameColumn]
        
    }
    
    static func ==(lhs: Chat, rhs: Chat) -> Bool {
        return lhs.displayName == rhs.displayName ||
        lhs.id == rhs.id
        
    }
}

struct Handle: Equatable, Comparable {
    let id: Int
    let value: String?
    
    init(row: Row) {
        let idColumn = Expression<String?>("id")
        let rowIDColumn = Expression<Int>("ROWID")
        
        
        self.id = row[rowIDColumn]
        self.value = row[idColumn]
        
    }
    
    static func ==(lhs: Handle, rhs: Handle) -> Bool {
        guard let lhsValue = lhs.value,
            let rhsValue = rhs.value else { return false }
        return lhsValue == rhsValue
    }
    
    static func <(lhs: Handle, rhs: Handle) -> Bool {
        guard let lhsValue = lhs.value,
            let rhsValue = rhs.value else { return false }
        return lhsValue < rhsValue
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
