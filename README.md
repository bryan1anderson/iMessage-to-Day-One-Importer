# iMessage-to-Day-One-Importer

The app grabs all the iMessages from Chat.db and begins an import into Day One App

SETUP:

`func importMessagesForAllNonImportedDates()` is the method that begins a recursive update for all entries after a certain date

You can set the date you would like to begin importing at the beginning of that method

Trigger the import by clicking on the menu item "Import Non-Imported Dates"

For right now it only tracks days there were imported. It only marks a date imported after all messages on that date are imported, so if you kill the app during an import, and then begin again you may end up with duplicates

Manually importing the last day will soon be changed to manually importing a specific date. Right now its just yesterday, but will introduce UI to import any specific day. I implemented this before I had the date tracking system worked out but it has been useful in cases where I needed to compare recent messages to make sure I wasn't discarding important info

Right now resetting the dates is manual. From `applicationDidFinishLaunching` uncomment `//        self.importedDates = []`
Comment again, rebuild and then begin import. Because individual chats are not tracked, plan to have duplicates. I've just been erasing all messages and beginning the import process again 

TODO:
import picture attatchments
Import specific dates
Move to an async import so the app doesn't become unresponsive during imports
Provide some feedback as to what is importing
Add UI to reset imported dates
Add way to track indvidual messages threads that have already been imported.. Maybe. Kind of difficult since Day One doesn't allow me to peek in, so I have to create identifiers for each chat and then persist them. 
