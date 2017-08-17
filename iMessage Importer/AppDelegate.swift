//
//  AppDelegate.swift
//  iMessage Importer
//
//  Created by Bryan on 8/7/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Cocoa
import NotificationCenter

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {

    @IBOutlet weak var window: NSWindow!
    
    var statusItem: NSStatusItem!
    
    let importer = MessageImporter(date: Date())
    
    var importDatesMenuItem: NSMenuItem?
    
    var importedDates: [Date] {
        get {
            let defaults = UserDefaults.standard
            let importedDates = defaults.object(forKey: "imported_dates") as? [Date] ?? []
            return importedDates
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: "imported_dates")
            defaults.synchronize()
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        importer.delegate = self
        
        let center = NSUserNotificationCenter.default
        center.delegate = self
        let nots = center.scheduledNotifications
        
//        self.importedDates = []
//        importMessages()

//        scheduleNotification()
        setMenu()

    }
    
    func setMenu() {
        let statusItem = NSStatusBar.system().statusItem(withLength: -1)
        self.statusItem = statusItem
        
        if let button = statusItem.button {
            button.image = #imageLiteral(resourceName: "StatusBarButtonImage")
            //            button.action = Selector("printQuote:")
        }
        
        let menu = NSMenu()
        
        //        menu.addItem(NSMenuItem(title: "Print Quote", action: Selector("printQuote:"), keyEquivalent: "P"))
        let importDatesMenuItem = NSMenuItem(title: "Imported Non-Imported Dates", action: #selector(AppDelegate.importMessagesForAllNonImportedDates), keyEquivalent: "i")
        self.importDatesMenuItem = importDatesMenuItem
        menu.addItem(importDatesMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Manually Import Yesterday", action: #selector(AppDelegate.manuallyImport), keyEquivalent: "i"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit iMessage Importer", action: #selector(AppDelegate.terminate), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    func scheduleNotification() {
        
        let defaults = UserDefaults.standard
        var identifier = defaults.object(forKey: "notification_identifier") as? String
        
        if let identifier = identifier {
            
        } else {
            identifier = NSUUID().uuidString
            defaults.set(identifier, forKey: "notification_identifier")
        }
        
        let notification = NSUserNotification()
        
        // All these values are optional
        notification.title = "Began import of iMessages"
        notification.subtitle = "Don't quit the app"
        notification.informativeText = "If import has not already occurred for the day, this will begin now"
        notification.soundName = NSUserNotificationDefaultSoundName
        notification.identifier = identifier
        var c = DateComponents()
        c.hour = 3
        notification.deliveryRepeatInterval = c
        NSUserNotificationCenter.default.scheduleNotification(notification)
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        let defaults = UserDefaults.standard
        let identifier = defaults.object(forKey: "notification_identifier") as? String
        
        if notification.identifier == identifier {
            importMessages(date: Date())
        }
        
        return true
    }
    


    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        
    }

    @objc func terminate() {
        
    }
    
    @objc func manuallyImport() {
        print("beginning import")
        let currentDate = Date().yesterday
        importer.getMessages()
        var importedDates = self.importedDates
        importedDates.append(currentDate)
        self.importedDates = importedDates
    }
    
    @objc func importMessagesForAllNonImportedDates() {
        self.importDatesMenuItem?.isEnabled = false
        
        var startC = DateComponents()
        startC.year = 2017
        startC.month = 8
        startC.day = 14
        
//        var endC = DateComponents()
//        endC.year = 2017
//        endC.month = 6
//        endC.day = 29
        
        guard var date = Calendar.current.date(from: startC) else { return }
//        let endDate = Calendar.current.date(from: endC) else { return } // first date
        let endDate = Date().yesterday // last date
        
        var importedDates = self.importedDates
        while date <= endDate {

            date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
            let contains = importedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) })
            if !contains {
                print("importing: \(date)")
                importMessages(date: date)
                importedDates.append(date)
                self.importedDates = importedDates

            } else {
                print("already imported date: \(date)")
            }
        }
        self.importDatesMenuItem?.isEnabled = false

        
    }
    
    func importMessages(date: Date) {
        let importer = MessageImporter(date: date)
        importer.delegate = self
        importer.getMessages()
    }

}

extension AppDelegate: MessageImporterDelegate {
    
    func didGet(chatMessageJoins: [ChatMessageJoin]) {
        for chatMessageJoin in chatMessageJoins {
            chatMessageJoin.getReadableString(completion: { (entry) in
                guard let command = self.createEntryCommand(for: entry) else { return }
                let returned = run(command: command)
                print(returned)
            })
            
        }
    }
    
    func createEntryCommand(for entry: Entry) -> String? {
        let c = Calendar.current.dateComponents([.day, .month, .year], from: entry.date)
        guard let day = c.day,
            let month = c.month,
            let year = c.year else { return nil }
        
        let tags = entry.tags.joined(separator: " ")
        let command = "/usr/local/bin/dayone2 -j 'iMessages' --tags='\(tags)' --date='\(month)/\(day)/\(year)' new '\(entry.title)' '\(entry.body)'"
        print(command)
        return command
    }
}

func run(command: String) -> String {
    let pipe = Pipe()
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", String(format:"%@", command)]
    task.standardOutput = pipe
    let file = pipe.fileHandleForReading
    task.launch()
    if let result = NSString(data: file.readDataToEndOfFile(), encoding: String.Encoding.utf8.rawValue) {
        return result as String
    }
    else {
        return "--- Error running command - Unable to initialize string from file data ---"
    }
    
}
