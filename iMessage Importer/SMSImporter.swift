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
//            print(error)
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
    

    var newJoins: [ChatMessageJoin] = [] {
        didSet {
            delegate.didGet(chatMessageJoins: newJoins)
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
    
    func importDbs() {
//        self.importOldDbs()
        self.importNewDbs()
    }
    
    
    private func importOldDbs() {
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
    
    
    private func importNewDbs() {
        let joins = newDBs.flatMap({ (newDB) -> [ChatMessageJoin]? in
            
//            do {
          
                let dbs = newDB.dbs
                
                
                let groupID = Expression<Int?>("group_id")
                
                let handleID = Expression<Int?>("handle_id")
                
                let madridHandle = Expression<String?>("madrid_handle")
                
                //MESSAGE STUFF
                let messageTable = Table("message")
                
                //CHAT STUFF
                let chatTable = Table("chat")
                let rowID = Expression<Int>("ROWID")
                let guid = Expression<String?>("guid")
                let chatIdentifier = Expression<String?>("chat_identifier")
                
                
                //CHAT MESSAGE JOIN STUFF
                let chatMessageJoinTable = Table("chat_message_join")
                let chatID = Expression<Int>("chat_id")
                let messageID = Expression<Int?>("message_id")
                let itemType = Expression<Int>("item_type")
                //            let groupID = Expression<Int?>("group_id")
                
                //CHAT HANDLE JOIN
                let chatHandleJoinTable = Table("chat_handle_join")
                let handlesTable = Table("handle")
                
                //Get a list of chats
                //select all messages from chats using the JOIN
                
                let messagePieces = Table("msg_pieces")
                
                let dateColumn = Expression<Int>("date")
                
                
                //Multiply by 1 billion because iMessage upgraded to nanoseconds in iOS 11 and High Sierra,
                //probably do a check to see if the number is greater than a 1 Billion, if not X by 1 billion
            let yesterdayMidnight = Int(date.yesterdayMidnight.timeIntervalSinceReferenceDate)
            let midnight = Int(date.midnight.timeIntervalSinceReferenceDate)
            
            let yesterdayMidnight1970 = Int(date.yesterdayMidnight.timeIntervalSince1970)
            let midnight1970 = Int(date.midnight.timeIntervalSince1970)
            
            
                let messagesQuery = messageTable.filter((dateColumn >= yesterdayMidnight && dateColumn < midnight) || (dateColumn >= yesterdayMidnight1970 && dateColumn < midnight1970))
                //
                //            //                    let messagesQuery = messageTable
                //Get all messages in todays date
                //This is avoids going through days that don't have messages
                guard let messages = try? dbs.prepare(messagesQuery).flatMap({ $0 }) else { return nil }
                if messages.count <= 0 {
                    print("no messages")
                    return nil }
                do {
                    let chatsQuery = chatTable
                    //For each chat
                    let chatMessageJoins = try dbs.prepare(chatsQuery).flatMap({ (chatRow) -> ChatMessageJoin? in
                        
                        
                        
                        let id = chatRow[rowID]
                        //Find all handles in the chat
                        let chatHandleJoinQuery = chatHandleJoinTable.filter(chatID == id).select(handleID)
                        let handleIDs = (try? dbs.prepare(chatHandleJoinQuery).flatMap({ $0[handleID] })) ?? []
                        let handlesQuery = handlesTable.filter(handleIDs.contains(rowID))
                        let handles = try? dbs.prepare(handlesQuery).flatMap({ $0 })
                        
                        //Find all message ID's in the CHAT
                        let chatMessageJoinQuery = chatMessageJoinTable.filter(chatID == id).select(messageID)
                        guard let messageIDs = try? dbs.prepare(chatMessageJoinQuery).flatMap({ $0[messageID] }) else { return nil }
                        //                    print(messageIDs)
                        
                        
                        //Find all messages for the messageIDs
                        //Order them by most recent
                        //Filter by todays date
                        //Filter by itemType == 0. I don't know what other item_types do, but they seem to not be readable/viewable
                        let messagesQuery = messageTable.filter(messageIDs.contains(rowID)).order(date).filter(itemType == 0).filter(dateColumn >= yesterdayMidnight && dateColumn < midnight)
                        
                        //Get the messages
                        guard let messages = try? dbs.prepare(messagesQuery).flatMap({ $0 }) else { return nil }
                        //                    let dates = messages.flatMap({ $0[date] })
                        //                    print(dates)
                        
                        //Don't include this chat if there aren't messages on DATE
                        if messages.count <= 0 { return nil }
                        
                        let chat = Chat(row: chatRow)
                        let messagesArray = messages.flatMap({ Message(row: $0) })
                        if messagesArray.count == 1,
                            let first = messagesArray.first,
                            first.handleID == 0, first.isFromMe == false, first.text == nil {
                            //THis handles the case with seemingly corrupted messages with a HandleID of 0, that aren't from me
                            return nil
                        }
                        let handlesArray = handles?.flatMap({ Handle(row: $0) })
                        
                        //This object is a join for a chat, it's messages, it's handles, and the date.
                        let chatMessageJoin = ChatMessageJoin(chat: chat, messages: messagesArray, handles: handlesArray, date: date)
                        return chatMessageJoin
                    })
                    //Once the flatmap is complete, chatMessageJoins contains all the chats/messages/handles to create an entry on a certain date
                    return chatMessageJoins
                    
                    
                    
                } catch {
                    print(error)
                    return nil
                }
            
//            }
//            catch {
//                print(error)
//                return nil
////                let alert = NSAlert()
////                alert.informativeText = error.localizedDescription
////                alert.messageText = "FATAL ERROR"
////                alert.addButton(withTitle: "OKAY")
////                alert.alertStyle = .critical
////                
////                let willReset = alert.runModal() == NSAlertFirstButtonReturn
////                if willReset {
////                    fatalError(error.localizedDescription)
////                }
//                
//            }

        })
        let chatJoins = joins.flatMap({ $0 }).removeDuplicates()
        if chatJoins.count > 0 {
            print("importing new joins")
        }
        self.newJoins = chatJoins
    }
}


func containSameElements<T: Comparable>(_ array1: [T], _ array2: [T]) -> Bool {
    guard array1.count == array2.count else {
        return false // No need to sorting if they already have different counts
    }
    
    return array1.sorted() == array2.sorted()
}


//step 1, get all the msg_groups
//for each msg_group get all the messages on date
//
