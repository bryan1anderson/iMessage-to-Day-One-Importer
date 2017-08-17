//
//  Group.swift
//  iMessage Importer
//
//  Created by Bryan on 8/8/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation
import SQLite

//struct Group: Equatable {
//    let groupID: String
//    var messages: [Message]
//    let addressValues: [String]
//    
//    init?(groupID: String?, messages: [Message]) {
//        guard let groupID = groupID else {
//            return nil }
//        self.groupID = groupID
//        if messages.count <= 0 {
//            return nil
//        }
//        self.messages = messages.sorted()
//        let addresses = messages.flatMap({ $0.address }).removeDuplicates()
//        self.addressValues = addresses
//        
//    }
//    
//    static func ==(lhs: Group, rhs: Group) -> Bool {
//        return lhs.groupID == rhs.groupID  && lhs.messages == rhs.messages
//    }
//    
//}
