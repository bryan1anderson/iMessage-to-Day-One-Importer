//
//  ChatMessageJoin.swift
//  iMessage Importer
//
//  Created by Bryan on 9/19/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation
import SQLite
import Contacts

struct ChatMessageJoin: ContactsProtocol, Equatable {
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
    
    static func ==(lhs: ChatMessageJoin, rhs: ChatMessageJoin) -> Bool {
        let messagesAreSame = containSameElements(lhs.messages, rhs.messages)
        let handlesAreSame = containSameElements(lhs.handles ?? [], rhs.handles ?? [])
        return lhs.chat == rhs.chat &&
            messagesAreSame &&
        handlesAreSame
        //        return lhs.groupID == rhs.groupID  && lhs.messages == rhs.messages
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
        if conversationName != nil {
            //comment out this return, i'm recursively updating all the ones I accidently missed
//            return
        } else {
            conversationName = contacts.first?.handle.value
        }
        let title = "Messages with: \(conversationName ?? "UNKNOWN")"
        
        var text = ""
        
        /*
         `31-Dec-11`         `Brantly`    What are you doing tonight?
         */
        
        let messages = self.messages.sorted(by: { $0.date < $1.date })
        for message in messages {
            
            
            let handle = self.getHandle(message: message)
            let contact = contacts.first(where: { $0.handle == handle })
            let firstName = contact?.contacts.first?.givenName
            
            //if handleID == 0, handle is ME
            let meString = "### Me"
            let name = message.handleID == 0 ? meString : message.isFromMe ? meString : "#### \(firstName ?? handle?.value ?? "UNKNOWN NAME")"
            
            let messageText = message.text ?? ""
            let line = "\n \(name)   \n \(messageText) \n ###### \(message.dateString()) \n "
            text.append(line)
            if let attachments = message.attachments {
                for attachment in attachments {
                    guard attachment.mimeType.type.description == MimeType.TopType.image.description else { continue }
                    text.append("\n[{photo}]\n")
                }
            }
        }
        
        //        group.notify(queue: .main) {
        var tags = [String]()
        if let conversationName = conversationName {
            tags.append(conversationName)
        } else {
            tags.append("UNKNOWN")
        }
        
//        if tags.count > 0 {
//            return
//        } else {
//            print("missing tags")
//        }
        let escapedString = text.replacingOccurrences(of: "\n", with: "\n").replacingOccurrences(of: "“", with: "").replacingOccurrences(of: "”", with: "").replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "\'", with: "")
        
        let attachments = messages.flatMap({ $0.attachments ?? [] })
        let hasAttachments = attachments.count > 0
        
        let entry = Entry(date: date.yesterday, tags: tags, title: title, body: escapedString, hasAttachments: hasAttachments, attachments: attachments)
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
