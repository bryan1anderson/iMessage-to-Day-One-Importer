//
//  MessageImportProtocol.swift
//  iMessage Importer
//
//  Created by Bryan on 8/7/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation
import SQLite
import Contacts

protocol MessageImporterDelegate {
    func didGet(chatMessageJoins: [ChatMessageJoin])
    func didGet(oldGroupJoins: [GroupMessageMemberJoin])
}

class MessageImporter {
    
    let chatDB: File
    
    var delegate: MessageImporterDelegate!
    let date: Date
    var chatMessageJoins = [ChatMessageJoin]() {
        didSet { delegate.didGet(chatMessageJoins: chatMessageJoins) }
    }
    
    init(date: Date) {
        do  {
            let originFolder = try Folder.home.subfolder(atPath: "/Library/Messages")
            guard let chatDB = try? originFolder.file(named: "chat.db") else { fatalError("unable to find chat.db") }
            self.chatDB = chatDB
            self.date = date
//            getMessages()
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func getMessages() {
        //Get all messages based off of groupID's. Just fetch groupID's, remove duplicates
        
        do {
            let path = chatDB.path
            let dbs = try Connection(path)
            
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
            let yesterdayMidnight = Int(date.yesterdayMidnight.timeIntervalSinceReferenceDate) * 1000000000
            let midnight = Int(date.midnight.timeIntervalSinceReferenceDate) * 1000000000
            let messagesQuery = messageTable.filter(dateColumn >= yesterdayMidnight && dateColumn < midnight)
//
//            //                    let messagesQuery = messageTable
            //Get all messages in todays date
            //This is avoids going through days that don't have messages
            guard let messages = try? dbs.prepare(messagesQuery).flatMap({ $0 }) else { return }
            if messages.count <= 0 {
                print("no messages")
                return }
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
                self.chatMessageJoins = chatMessageJoins
                
           
           
            } catch {
                print(error)
            }
            
        } catch {
            print(error)
            fatalError(error.localizedDescription)

        }
    }
    
    
    
}

struct Entry {
    let date: Date
    let tags: [String]
    let title: String
    let body: String
}


struct ChatMessageJoin: ContactsProtocol {
    let chat: Chat
    let messages: [Message]
    let handles: [Handle]?
    let date: Date
    
    init(chat: Chat, messages: [Message], handles: [Handle]?, date: Date) {
        self.chat = chat
        self.messages = messages
        self.handles = handles
        self.date = date
    }
    
    func getNumbers(handles: [Handle]) -> [String] {
        let handles = handles.flatMap({ $0.value })
        return handles
        
    }
    
    
    func getNumber(handle: Row) -> String? {
        let handleIdentifier = Expression<String?>("id")
        let value = handle[handleIdentifier]
        return value
    }
    
    
    
    
    func getReadableString(completion: @escaping (_ entry: Entry) -> ()) {

        
        
//        let handleID = Expression<Int>("handle_id")
        
        var conversationName = chat.displayName
        
//            let group = DispatchGroup()
        
//            var contactsArray = [CNContact]()
        let handles = self.handles ?? []

//        group.enter()
        let contacts = handles.flatMap({ getContact(handle: $0) })
       
        if conversationName == nil || conversationName == "" {
            let contactsArray = contacts.flatMap({ $0.contacts })
            conversationName = self.getNameString(for: contactsArray)
        }

        let title = "Messages with: \(conversationName ?? "UNKNOWN")"
        
        var text = ""
        
        /*
         `31-Dec-11`		 `Brantly`	What are you doing tonight?
         */
        
        let messages = self.messages.sorted(by: { $0.date < $1.date })
        for message in messages {
           
            
            let handle = self.getHandle(message: message)
            let contact = contacts.first(where: { $0.handle == handle })
            let firstName = contact?.contacts.first?.givenName
            
            //if handleID == 0, handle is ME
            let name = message.handleID == 0 ? "Me" : message.isFromMe ? "Me" : firstName ?? handle?.value ?? "UNKNOWN NAME"
            
            let messageText = message.text ?? ""
            let line = "> \n `\(name)`   \n> \(messageText) \n `\(message.dateString())` \n "
            text.append(line)
        }
        
//        group.notify(queue: .main) {
        var tags = [String]()
        if let conversationName = conversationName {
            tags.append(conversationName)
        }
        let escapedString = text.replacingOccurrences(of: "\n", with: "\n").replacingOccurrences(of: "“", with: "").replacingOccurrences(of: "”", with: "").replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "\'", with: "")

        let entry = Entry(date: date.yesterday, tags: tags, title: title, body: escapedString)
            completion(entry)
//        }
        
        
    }
    
    
    
    func getContact(handle: Handle) -> Contact {

        guard let number = handle.value else { return Contact(handle: handle, contacts: []) }
        
        let group = DispatchGroup()
        group.enter()
        var contactsArray = [CNContact]()
        getContacts(phoneNumber: number) { (contacts) in
            contactsArray = contacts
            group.leave()
        }
        group.wait()
        let contact = Contact(handle: handle, contacts: contactsArray)
        return contact
    }
//
    func getHandle(message: Message) -> Handle? {

        let handleID = message.handleID
        let handle = handles?.first(where: { $0.id == handleID })
        return handle
    }
//
    func dateString(for message: Row) -> String {
        let date = Expression<Int>("date")
        
        let interval = Double(message[date]) / 1000000000
        let messageDate = Date(timeIntervalSinceReferenceDate: interval)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        let dateString = dateFormatter.string(from: messageDate)
        return dateString
    }
    
    
    
    //I need to get all the chats with messages in a particular date

}
