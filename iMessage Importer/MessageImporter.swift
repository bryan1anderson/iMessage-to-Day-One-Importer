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
            let alert = NSAlert()
            alert.informativeText = error.localizedDescription
            alert.messageText = "FATAL ERROR"
            alert.addButton(withTitle: "OKAY")
            alert.alertStyle = .critical
            
            let willReset = alert.runModal() == NSAlertFirstButtonReturn
            if willReset {
                fatalError(error.localizedDescription)
            }

        }
    }
    
    
    
}

struct Entry {
    let date: Date
    let tags: [String]
    let title: String
    let body: String
}



