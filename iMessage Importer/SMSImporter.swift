//
//  SMSImporter.swift
//  iMessage Importer
//
//  Created by Bryan on 8/26/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation
import SQLite
import Contacts

struct ContactDatabase {
//
    let contactsTable = Table("ABPerson")
    let multiValue = Table("ABMultiValue")

    let oldContacts: [OldContact]
    
    init?(file: File) {
        do {
            let path = file.path
            let dbs = try Connection(path)
            
            let contactsTable = Table("ABPerson")
            let multiValue = Table("ABMultiValue")

            try dbs.prepare(contactsTable)
            try dbs.prepare(multiValue)
            
            //                let first = Expression<String?>("First")
            //                let last = Expression<String?>("Last")
            //                let middle = Expression<String?>("Middle")
            
            let recordID = Expression<Int?>("record_id")
            let rowID = Expression<Int?>("ROWID")
            
            let value = Expression<String?>("value")
            let contactsArray = try dbs.prepare(contactsTable).flatMap({(row) -> OldContact? in
                guard let row_id = row[rowID] else { return nil }
                let multiValues = multiValue.filter(recordID == row_id)
                let values = try dbs.prepare( multiValues).flatMap({ $0[value] })
                return OldContact(row: row, values: values)

            })
//            let contactsArray = try dbs.prepare(contactsTable).flatMap({ (row) -> OldContact? in
//            })
            self.oldContacts = contactsArray
        } catch {
            return nil
            print(error)
        }

    }
}

struct NewDatabase {
    let chatTable = Table("chat")
    let messageTable = Table("message")
    let chatMessageJoinTable = Table("chat_message_join")
    let chatHandleJoinTable = Table("chat_handle_join")
    let handlesTable = Table("handle")

    let file: File
    let dbs: Connection
    
    init?(file: File) {
        self.file = file
        do {
            let path = file.path
            let dbs = try Connection(path)
            try dbs.prepare(chatTable)
            try dbs.prepare(chatMessageJoinTable)
            try dbs.prepare(messageTable)
            try dbs.prepare(chatHandleJoinTable)
            try dbs.prepare(handlesTable)
//            print("found new database: \(file.name)")
            self.dbs = dbs
            
        } catch {
//            print(error)
            return nil
        }
    }
    
}


struct OldDatabase {
    let messageTable = Table("message")
    let messageGroupTable = Table("msg_group")
    let groupMemberTable = Table("group_member")
    
    let file: File
    let dbs: Connection
    
    init?(file: File) {
        self.file = file
        do {
        let path = file.path
        let dbs = try Connection(path)
            try dbs.prepare(messageGroupTable)
            try dbs.prepare(groupMemberTable)
            try dbs.prepare(messageTable)
//            print("found old database: \(file.name)")
        self.dbs = dbs
            
        } catch {
//            print(error)
            return nil
        }
    }

}

class ContactImporter {
    let contactDBs: [ContactDatabase]
    var oldContacts: [OldContact] = []

    static let shared = ContactImporter()
    
    init() {
        do {
            let originFolder = try Folder(path: "~/Developer/Personal/iMessages/iMessages")
            let files = originFolder.files.filter({$0.extension == "db" })
            self.contactDBs = files.flatMap({ ContactDatabase(file: $0) })
            importOldContacts()
        }
        catch {
            fatalError("unable to find folder")
        }
    }
    
    func importOldContacts() {
        let oldContacts = contactDBs.flatMap({ $0.oldContacts })
        self.oldContacts = oldContacts
    }

}

class SMSImporter {
    
    let chatDBs: [File]
    let date: Date
    
    let oldDBs: [OldDatabase]
    let newDBs: [NewDatabase]
    
    var oldJoins: [GroupMessageMemberJoin] = [] {
        didSet {
            delegate.didGet(oldGroupJoins: oldJoins)
        }
    }
    
    var delegate: MessageImporterDelegate!

    
    init(date: Date) {
        self.date = date
        do {
            let originFolder = try Folder(path: "~/Developer/Personal/iMessages/iMessages")
            let files = originFolder.files.filter({$0.extension == "db" })
            self.oldDBs = files.flatMap({ OldDatabase(file: $0) })
            self.newDBs = files.flatMap({ NewDatabase(file: $0) })
            self.chatDBs = files
        } catch {
            fatalError("unable to find old databases")
        }

    }
    
    
    func importOldDbs() {
        let ROWIDColumn = Expression<Int>("ROWID")
        let groupIDColumn = Expression<Int>("group_id")
        let addressColumn = Expression<String>("address")
        let dateColumn = Expression<Int>("date")
        
        
        
        //Time interval since reference date is Jan 2001. We need both 1970 and 2001 because they are used together
        let yesterdayMidnight = Int(date.yesterdayMidnight.timeIntervalSinceReferenceDate)
        let midnight = Int(date.midnight.timeIntervalSinceReferenceDate)
        
        let yesterdayMidnight1970 = Int(date.yesterdayMidnight.timeIntervalSince1970)
        let midnight1970 = Int(date.midnight.timeIntervalSince1970)
        
        //for each OLDDB, create an array of groupMessageMemberJoin. We'll flatten the array of arrays later
        let joinsArray = oldDBs.flatMap { (db) -> [GroupMessageMemberJoin]? in
            let dbs = db.dbs
            
            do {
                //Check to see if this date has any messages, if not return nil to avoid more work
                let messagesQuery = db.messageTable.order(date).filter((dateColumn >= yesterdayMidnight && dateColumn < midnight) || (dateColumn >= yesterdayMidnight1970 && dateColumn < midnight1970))
                
                guard let messages = try? dbs.prepare(messagesQuery).flatMap({ $0 }) else { return nil }
                if messages.count <= 0 {
//                    print("no messages")
                    return nil }
                
                //for each message group
                let dbJoins = try dbs.prepare(db.messageGroupTable).flatMap({ (groupRow) -> GroupMessageMemberJoin? in
                    let id = groupRow[ROWIDColumn]
                    
                    //Get all messages in that group, on that day
                    let messagesQuery = db.messageTable.filter(groupIDColumn == id).order(date).filter((dateColumn >= yesterdayMidnight && dateColumn < midnight) || (dateColumn >= yesterdayMidnight1970 && dateColumn < midnight1970))
                    
                    guard let messages = try? dbs.prepare(messagesQuery) else { return nil }
                    
                    //Get all members of that group
                    let membersQuery = db.groupMemberTable.filter(groupIDColumn == id)
                    let groupMembers = try? dbs.prepare(membersQuery)
                    
                    let members = groupMembers?.flatMap({ Member(row: $0) })
                    
                    let group = Group(row: groupRow)
                    let oldMessages = messages.flatMap({ OldMessage(row: $0) })
                    if oldMessages.count < 1 {
                        return nil
                        //Don't include any groups without messages on this day
                    }
                    return GroupMessageMemberJoin(group: group, messages: oldMessages, members: members, date: date)
                })
                
                return dbJoins.count > 0 ? dbJoins : nil
            } catch {
                return nil
            }
            
        }
        //Flatten the array of arrays
        let combinedJoins = joinsArray.flatMap({ $0 })
        if combinedJoins.count > 0 {
            //Success!
            print("messages imported")
//            print(combinedJoins)
        }
        //Remove the duplicates. GroupMessageMemberJoins have built in equatability, check the classes contained to see how that works
        //Basically members == members && messages == messages
        let nonDuplicates = combinedJoins.removeDuplicates()
        self.oldJoins = nonDuplicates
    }
    
}


func containSameElements<T: Comparable>(_ array1: [T], _ array2: [T]) -> Bool {
    guard array1.count == array2.count else {
        return false // No need to sorting if they already have different counts
    }
    
    return array1.sorted() == array2.sorted()
}
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
         `31-Dec-11`		 `Brantly`	What are you doing tonight?
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
            let name = message.isFromMe ? "Me" : firstName ?? handle ?? "UNKNOWN NAME"
            
            let messageText = message.text ?? ""
            let line = "\n `\(name)`   \(messageText) \n `\(message.dateString())` \n "
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

//step 1, get all the msg_groups
//for each msg_group get all the messages on date
//
