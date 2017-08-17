//
//  ContactsProtocol.swift
//  iMessage Importer
//
//  Created by Bryan on 8/8/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Foundation
import Contacts
import SQLite

protocol ContactsProtocol {
    
}

extension ContactsProtocol {
    
    
    func getNameString(for contacts: [CNContact]) -> String? {

        
        if contacts.count > 0 {
            //                    print(contacts)
            let names = contacts.flatMap({ "\($0.givenName.capitalized) \($0.familyName.capitalized)" }).removeDuplicates()
            let nameString = names.joined(separator: " ")
            return nameString
            
        } else {
            return nil
        }
        
        
    }
    
    
    
    
    func requestForAccess(completionHandler: @escaping (_ accessGranted: Bool) -> Void) {
        // Get authorization
        let authorizationStatus = CNContactStore.authorizationStatus(for: CNEntityType.contacts)
        
        // Find out what access level we have currently
        switch authorizationStatus {
        case .authorized:
            completionHandler(true)
            
        case .denied, .notDetermined:
            CNContactStore().requestAccess(for: CNEntityType.contacts, completionHandler: { (access, accessError) -> Void in
                if access {
                    completionHandler(access)
                }
                else {
                    if authorizationStatus == CNAuthorizationStatus.denied {
                        //                        DispatchQueue.main.async(execute: { () -> Void in
                        //                            let message = "\(accessError!.localizedDescription)\n\nPlease allow the app to access your contacts through the Settings."
                        //                            self.showMessage(message)
                        //                        })
                    }
                }
            })
            
        default:
            completionHandler(false)
        }
    }
    
    func getContacts(for phoneNumbers: [String], completion: @escaping ([CNContact]) -> ()) {
        var contacts = [CNContact]()
        
        let group = DispatchGroup()
        
        group.notify(queue: .main) {
            print("Finished all requests.")
            completion(contacts)
        }
        for phoneNumber in phoneNumbers {
            group.enter()
            getContacts(phoneNumber: phoneNumber, completion: { (contactArray) in
                contacts += contactArray
                group.leave()
            })
        }
    }
    
    func getContacts(phoneNumber: String, completion: @escaping ([CNContact]) -> ()) {
        
        self.requestForAccess { (accessGranted) -> Void in
            if accessGranted {
                let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactImageDataKey, CNContactPhoneNumbersKey]
                var contacts = [CNContact]()
                var message: String!
                
                let contactsStore = CNContactStore()
                do {
                    
                    try contactsStore.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])) {
                        (contact, cursor) -> Void in
                        if (!contact.phoneNumbers.isEmpty) {
                            let phoneNumberToCompareAgainst = phoneNumber.components(separatedBy: NSCharacterSet.decimalDigits.inverted).joined(separator: "")
                            for phoneNumber in contact.phoneNumbers {
                                if let phoneNumberStruct = phoneNumber.value as? CNPhoneNumber {
                                    let phoneNumberString = phoneNumberStruct.stringValue
                                    let phoneNumberToCompare = phoneNumberString.components(separatedBy: NSCharacterSet.decimalDigits.inverted).joined(separator: "")
                                    if phoneNumberToCompare.contains(phoneNumberToCompareAgainst) || phoneNumberToCompareAgainst.contains(phoneNumberToCompare)
                                        && phoneNumberString.characters.count > 5 {
                                        contacts.append(contact)
                                    }
                                }
                            }
                        }
                        
                    }
                    
                    if contacts.count == 0 {
                        message = "No contacts were found matching the given phone number."
                    }
                }
                catch {
                    message = "Unable to fetch contacts."
                    completion([])
                }
                
                if message != nil {
                    //                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    //                        self.showMessage(message)
                    //                    })
                    completion([])
                }
                else {
                    // Success
                    //                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    // Do someting with the contacts in the main queue, for example
                    /*
                     self.delegate.didFetchContacts(contacts) <= which extracts the required info and puts it in a tableview
                     */
                    //                    print(contacts.count)
                    completion(contacts)
                    //                    guard let contact = contacts.first else { return }
                    //                        print(contacts) // Will print all contact info for each contact (multiple line is, for example, there are multiple phone numbers or email addresses)
                    //                        print(contact.givenName) // Print the "first" name
                    //                        print(contact.familyName) // Print the "last" name
                    //                        if contact.isKeyAvailable(CNContactImageDataKey) {
                    //                            if let contactImageData = contact.imageData {
                    //                                print(UIImage(data: contactImageData)) // Print the image set on the contact
                    //                            }
                    //                        } else {
                    //                            // No Image available
                    //
                    //                        }
                    //                    })
                }
            } else {
                completion([])
            }
        }
        
        
    }
    
}
