//
//  GroupMessasgeMemberJoin.swift
//  iMessage Importer
//
//  Created by Bryan on 9/19/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation
import SQLite
import Contacts

struct GroupMessageMemberJoin: Equatable {
    let group: Group
    let messages: [OldMessage]
    let members: [Member]?
    let date: Date
    
    
    init(group: Group, messages: [OldMessage], members: [Member]?, date: Date) {
        self.group = group
        self.messages = messages
        self.members = members
        self.date = date
    }
    
    static func ==(lhs: GroupMessageMemberJoin, rhs: GroupMessageMemberJoin) -> Bool {
        let messagesAreSame = containSameElements(lhs.messages, rhs.messages)
        let membersAreSame = containSameElements(lhs.members ?? [], rhs.members ?? [])
        
        return messagesAreSame && membersAreSame
    }
}

extension GroupMessageMemberJoin: ContactsProtocol {
    
    func getNameString(for contacts: [OldContact]) -> String? {
        
        
        if contacts.count > 0 {
            //                    print(contacts)
            let names = contacts.flatMap({ "\($0.first?.capitalized ?? "") \($0.last?.capitalized ?? "")" }).removeDuplicates()
            let nameString = names.joined(separator: " ")
            return nameString
            
        } else {
            return nil
        }
    }
    
    
    func getReadableString(completion: @escaping (_ entry: Entry) -> ()) {
        
        
        
        //        let handleID = Expression<Int>("handle_id")
        
        
        //            let group = DispatchGroup()
        
        //            var contactsArray = [CNContact]()
        let members = self.members ?? []
        
        //        group.enter()
        let contacts = members.flatMap({ getContacts(member: $0) })
        var addressContacts = [CNContact]()
        
        //        if conversationName == nil || conversationName == "" {
        
        let phone = contacts.flatMap({ $0.values }).first
        let memberPhone =  members.flatMap({ $0.address }).first
        
        var conversationName = self.getNameString(for: contacts) ?? phone
        
        if conversationName != nil {
            //            return
        } else {
            conversationName = memberPhone
            
            addressContacts = self.members?.flatMap({ self.getContactsFromAddressBook(member: $0) }) ?? []
            let nameString = getNameString(for: addressContacts)
            if let nameString = nameString {
                conversationName = nameString
            }
        }
        //        }
        
        let title = "Messages with: \(conversationName ?? "UNKNOWN")"
        
        var text = ""
        
        /*
         `31-Dec-11`         `Brantly`    What are you doing tonight?
         */
        
        let messages = self.messages.sorted(by: { $0.date < $1.date })
        for message in messages {
            
            
            let handle = message.address
            let contact = contacts.first(where: { (oldContact) -> Bool in
                guard let handle = handle else { return false }
                return oldContact.values.contains(handle)
            })
            let firstName = contacts.first?.first ?? addressContacts.first?.givenName
            
            //if handleID == 0, handle is ME
            let meString = "### Me"
            
            let name = message.isFromMe ? meString : "#### \(firstName ?? handle ?? "UNKNOWN NAME")"
            
            let messageText = message.text ?? ""
            let line = "\n \(name)   \n \(messageText) \n ###### \(message.dateString()) \n "
            text.append(line)
        }
        
        //        group.notify(queue: .main) {
        var tags = [String]()
        if let conversationName = conversationName {
            tags.append(conversationName)
        } else {
            tags.append("UNKNOWN")
        }
        let escapedString = text.replacingOccurrences(of: "\n", with: "\n").replacingOccurrences(of: "“", with: "").replacingOccurrences(of: "”", with: "").replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "\'", with: "")
        
        let entry = Entry(date: date.yesterday, tags: tags, title: title, body: escapedString)
        completion(entry)
        //        }
        
        
    }
    
    func getContactsFromAddressBook(member: Member) -> [CNContact] {
        
        guard let number = member.address else { return [] }
        
        let group = DispatchGroup()
        group.enter()
        var contactsArray = [CNContact]()
        getContacts(phoneNumber: number) { (contacts) in
            contactsArray = contacts
            group.leave()
        }
        group.wait()
        //        let contact = Contact(handle: handle, contacts: contactsArray)
        return contactsArray
    }
    
    
    
    func getContacts(member: Member) -> [OldContact] {
        
        guard let number = member.address else { return [] }
        
        let filteredContacts = ContactImporter.shared.oldContacts.filter { (oldContact) -> Bool in
            
            let values = oldContact.values.filter({ (value) -> Bool in
                let value = value.cleaned
                let phoneNumberToCompare = value.components(separatedBy: NSCharacterSet.decimalDigits.inverted).joined(separator: "")
                if phoneNumberToCompare.contains(number) || number.contains(phoneNumberToCompare)
                    && phoneNumberToCompare.characters.count > 5 {
                    return true
                } else {
                    return false
                }
            })
            
            return values.count > 0
        }
        return filteredContacts
        
    }
}
