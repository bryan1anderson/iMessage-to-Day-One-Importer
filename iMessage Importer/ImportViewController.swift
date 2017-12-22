//
//  ImportViewController.swift
//  iMessage Importer
//
//  Created by Bryan on 9/1/17.
//  Copyright © 2017 Bryan Lloyd Anderson. All rights reserved.
//

import Cocoa

enum ImportType {
    case developer
    case user
}

class ImportViewController: NSViewController {
    
//    @IBOutlet weak var stackPickerRanges: NSStackView!
    @IBOutlet weak var buttonImportAll: NSButton!
    @IBOutlet weak var buttonCancel: NSButton!
    
    @IBOutlet weak var dateDefaultStartPicker: NSDatePicker!
    
    var shouldStopBeforeNextDate = false
    
//    @IBOutlet weak var dateOldStartPicker: NSDatePicker!
//    @IBOutlet weak var dateOldEndPicker: NSDatePicker!
//
//    @IBOutlet weak var dateiMessageStartPicker: NSDatePicker!
//    @IBOutlet weak var dateiMessageEndPicker: NSDatePicker!
//
//    
//    @IBOutlet weak var buttonImportOld: NSButton!
//    @IBOutlet weak var buttonImportiMessages: NSButton!
    
    @IBOutlet weak var labelStatus: NSTextField!
    @IBOutlet weak var labelStatusMessageTitle: NSTextField!
    
    let importQueue = DispatchQueue(label: "com.imessagesimport", qos: .utility)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setDatePickersInitialValue()
        labelStatus.stringValue = ""
        setImportType()
        
        buttonImportAll.alternateTitle = "Cancel"
        
//        importOld()
        // Do view setup here.
    }
    var importType: ImportType = .user {
        didSet { setImportType() }
    }
    func setImportType() {
//        switch importType {
//        case .developer:
//            stackPickerRanges.isHidden = false
//        case .user:
//            stackPickerRanges.isHidden = true
//        }
        
    }
    
    @IBAction func clickedImportOld(_ sender: NSButton) {
    }
    
    @IBAction func clickedImportiMessages(_ sender: NSButton) {
    }
    
    
    @IBAction func changedDateOldStart(_ sender: NSDatePicker) {
        self.dateOldStart = sender.dateValue
    }

    @IBAction func changedDateOldEnd(_ sender: NSDatePicker) {
        self.dateOldEnd = sender.dateValue
    }

    @IBAction func changedDateiMessagesStart(_ sender: NSDatePicker) {
        self.dateiMessagesStart = sender.dateValue
    }

    @IBAction func changedDateiMessagesEnd(_ sender: NSDatePicker) {
        self.dateiMessagesEnd = sender.dateValue
    }
    
    @IBAction func changedDefaultStartDate(_ sender: NSDatePicker) {
        self.dateDefaultStart = sender.dateValue
    }
    
    var currentWorkItems: [DispatchWorkItem] = []
    
    @IBAction func importAllNotImportedDates(_ sender: NSButton) {
        
        self.buttonCancel.isHidden = false
        self.buttonImportAll.isEnabled = false
        NSAnimationContext.runAnimationGroup({ (context) in
            context.duration = 0.5
            self.buttonCancel.animator().alphaValue = 1
        }) {
            print("completed")
        }
        let workItem = DispatchWorkItem {
            self.importMessagesForAllNonImportedDates()
        }
        self.currentWorkItems.append(workItem)

        importQueue.async {
            workItem.perform()
        }
    }
    
    @IBAction func cllickedCancelImport(_ sender: NSButton) {
        
      
        NSApplication.shared().terminate(self)
    }
    
    @IBAction func clickedQuitAfterFinishingDate(_ sender: NSButton) {
        let alert = NSAlert()
        alert.informativeText = "All entries for the current date being imported will finish importing, before the next date begins the app will quit. This helps avoid duplicates on days"
        alert.messageText = "Quit app after current date finishes importing?"
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let willQuit = alert.runModal() == NSAlertFirstButtonReturn
        if willQuit {
            self.shouldStopBeforeNextDate = true
        }
    }
    
    @IBAction func resetImportedDates(_ sender: NSButton) {
        let alert = NSAlert()
        alert.informativeText = "Resetting dates will allow dates already imported to be reimported, this can result in duplicates"
        alert.messageText = "Reset Dates?"
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let willReset = alert.runModal() == NSAlertFirstButtonReturn
        if willReset {
            self.importedDates = []
        }
    }
    
}



extension ImportViewController {
    
    func importOld() {
        var startC = DateComponents()
        startC.year = 2014
        startC.month = 10
        startC.day = 21
        
        var endC = DateComponents()
        endC.year = 2014
        endC.month = 10
        endC.day = 23
        
        guard let start = Calendar.current.date(from: startC),
            let end = Calendar.current.date(from: endC) else { return }
        
        importQueue.async {
            self.importNonImportedOldMessages(startDate: start, endDate: end)
        }
    }
    
    @objc func importMessagesForAllNonImportedDates() {
//        self.importDatesMenuItem?.isEnabled = false
        self.buttonImportAll.isEnabled = false
        var startC = DateComponents()
        startC.year = 2017
        startC.month = 8
        startC.day = 25
        
        //        var endC = DateComponents()
        //        endC.year = 2017
        //        endC.month = 6
        //        endC.day = 29
        
        guard var date = self.dateDefaultStart else { return }
        //        let endDate = Calendar.current.date(from: endC) else { return } // first date
        let endDate = Date().yesterday // last date
        
        var importedDates = self.importedDates
        while date <= endDate {
            
            date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
            let contains = importedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) })
            if !contains {
                print("importing: \(date)")
//                let stringDate = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
                self.labelStatus.stringValue = ""
                self.labelStatusMessageTitle.stringValue = ""
                if self.shouldStopBeforeNextDate {
                    NSApplication.shared().terminate(self)
                    return
                }
                importMessages(date: date)
                importedDates.append(date)
                self.importedDates = importedDates
                
            } else {
                print("already imported date: \(date)")
                let formater = DateFormatter()
                formater.dateStyle = .medium
                let dateString = formater.string(from: date)
                self.labelStatus.stringValue = "already imported date: \(dateString)"
            }
        }
//        self.importDatesMenuItem?.isEnabled = false
        DispatchQueue.main.async {
            self.labelStatusMessageTitle.stringValue = "Finished importing"
            self.buttonCancel.isHidden = true
            self.buttonImportAll.isEnabled = true 
        }

    }
    
    func importMessages(date: Date) {
        let importer = MessageImporter(date: date)
        importer.delegate = self
        importer.getMessages()
    }
    
    @objc func importNonImportedOldMessages(startDate: Date, endDate: Date) {
//        var startC = DateComponents()
//        startC.year = 2009
//        startC.month = 9
//        startC.day = 20
//        
//        var endC = DateComponents()
//        endC.year = 2014
//        endC.month = 10
//        endC.day = 22
        
        //        var endC = DateComponents()
        //        endC.year = 2017
        //        endC.month = 6
        //        endC.day = 29
        var date = startDate
        let endDate = endDate.yesterday
//        guard var date = Calendar.current.date(from: startC),
//            let endDate = Calendar.current.date(from: endC)?.yesterday else { return }
        //        let endDate = Calendar.current.date(from: endC) else { return } // first date
        //        let endDate = Date().yesterday // last date
        
        //        var importedDates = self.importedDates
        while date <= endDate {
            
            date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
            print("importing: \(date)")
            self.labelStatus.stringValue = "importing: \(date)"
            
            self.importOldMessages(date: date)
            
            //            let contains = importedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) })
            //            if !contains {
            //                importMessages(date: date)
            //                importedDates.append(date)
            //                self.importedDates = importedDates
            
            //            } else {
            //                print("already imported date: \(date)")
            //            }
        }
        
    }
    func importOldMessages(date: Date) {
        let importer = SMSImporter(date: date)
        importer.delegate = self
        importer.importDbs()
    }

}

extension ImportViewController {
    
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

    
    func setDatePickersInitialValue() {
//        if let oldStart = self.dateOldStart {
//            dateOldStartPicker.dateValue = oldStart
//        }
//
//        if let oldEnd = self.dateOldEnd {
//            dateOldEndPicker.dateValue = oldEnd
//        }
//
//        if let iMessagesStart = self.dateiMessagesStart {
//        dateiMessageStartPicker.dateValue = iMessagesStart
//        }
//
//        if let iMessagesEnd = self.dateiMessagesEnd {
//            dateiMessageEndPicker.dateValue = iMessagesEnd
//        }
        
        if let defaultStart = self.dateDefaultStart {
            self.dateDefaultStartPicker.dateValue = defaultStart
        }

    }
    
    var dateDefaultStart: Date? {
        get {
            let defaults = UserDefaults.standard
            let date = defaults.object(forKey: "dateDefaultStart") as? Date
            return date
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: "dateDefaultStart")
            defaults.synchronize()
        }
    }

    
    var dateOldStart: Date? {
        get {
            let defaults = UserDefaults.standard
            let date = defaults.object(forKey: "dateOldStart") as? Date
            return date
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: "dateOldStart")
            defaults.synchronize()
        }
    }
    
    var dateOldEnd: Date? {
        get {
            let defaults = UserDefaults.standard
            let date = defaults.object(forKey: "dateOldEnd") as? Date
            return date
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: "dateOldEnd")
            defaults.synchronize()
        }
    }
    
    var dateiMessagesStart: Date? {
        get {
            let defaults = UserDefaults.standard
            let date = defaults.object(forKey: "dateiMessagesStart") as? Date
            return date
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: "dateiMessagesStart")
            defaults.synchronize()
        }
    }
    
    var dateiMessagesEnd: Date? {
        get {
            let defaults = UserDefaults.standard
            let date = defaults.object(forKey: "dateiMessagesEnd") as? Date
            return date
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: "dateiMessagesEnd")
            defaults.synchronize()
        }
    }
    
    
}

extension ImportViewController: MessageImporterDelegate {
    
    func didGet(chatMessageJoins: [ChatMessageJoin]) {
        for chatMessageJoin in chatMessageJoins {
            chatMessageJoin.getReadableString(completion: { (entry) in
                guard let command = self.createEntryCommand(for: entry) else { return }
                let returned = run(command: command)
                print(returned)
//                DispatchQueue.main.sync {
 //                }
            })
            
        }
    }
    
    func didGet(oldGroupJoins: [GroupMessageMemberJoin]) {
        for chatMessageJoin in oldGroupJoins {
            chatMessageJoin.getReadableString(completion: { (entry) in
                guard let command = self.createEntryCommand(for: entry) else { return }
                //                print(command)
                let returned = run(command: command)
                print(returned)
                DispatchQueue.main.sync {
                    self.labelStatusMessageTitle.stringValue = returned
                }
            })
            
        }
    }
    
    func createEntryCommand(for entry: Entry) -> String? {
        let c = Calendar.current.dateComponents([.day, .month, .year], from: entry.date)
        guard let day = c.day,
            let month = c.month,
            let year = c.year else { return nil }
        
        let tags = entry.tags.joined(separator: " ")
        let stringDate = DateFormatter.localizedString(from: entry.date, dateStyle: .medium, timeStyle: .none)
        
        let body = "\(entry.title) \(entry.body)"
        self.labelStatusMessageTitle.stringValue = "Importing: \(stringDate) \(entry.title)"
        let photosTags: String
        
        let photoAttachments = entry.attachments?.filter({ (attachment) -> Bool in
            let type = attachment.mimeType.type
            switch type {
            case .image: return true
            default: return false
            }
        })
        
        if let attachments = photoAttachments, photoAttachments?.count ?? 0 > 0 {
            let names = attachments.flatMap({$0.filename})
            let photos = names.joined(separator: " ")
            photosTags = " -p \(photos)"
        } else {
            photosTags = ""
        }
        let command = "/usr/local/bin/dayone2 -j 'iMessages'\(photosTags) --tags='\(tags)' --date='\(month)/\(day)/\(year)' new \'\(body)\'"
        print(command)
        return command
    }
}

