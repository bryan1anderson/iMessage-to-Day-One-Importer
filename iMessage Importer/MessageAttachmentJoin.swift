//
//  MessageAttachmentJoin.swift
//  iMessage Importer
//
//  Created by Bryan on 12/12/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation
import SQLite

struct MessageAttachmentJoin {
    let messageID: Int
    
    init?(messageID: Int?, dbs: Connection) {
        guard let messageID = messageID else { return nil }
        self.messageID = messageID
        
        

    }
    
}

