# iMessage-to-Day-One-Importer

The app grabs all the iMessages from Chat.db and begins an import into Day One App

## SETUP:
Create a new Journal in Day One, called `iMessages`
This app won't work unless you have this Journal inside DayOne
Install Day One CLI: http://help.dayoneapp.com/day-one-2-0/command-line-interface-cli

The IMPORT START DATE is used to set the first day you'd like to import. It then imports all days after that up to the day preceding the your current date. It does not include todays messages in the import

Trigger the import by clicking on the menu item "Import All Non Imported"

For right now it only tracks days there were imported. It only marks a date imported after all messages on that date are imported, so if you kill the app during an import, and then begin again you may end up with duplicates

Resetting the dates will allow messages to be imported on days that have already been imported. This may result in duplicates

## KNOWn ISSUES:
Make sure Don't Sign Code is the selected setting in Build Settings > Code Signing Identity
When code signing is enabled, it looks like some sandbox restrictions are disabling access to the iMessage DB

## TODO:
import picture attatchments

Import specific dates

Create way for importing iPhone backup messages. I currently have this working but am manually pointing to a specific folder and there is no UI for triggering this. The plan is find all the iPhone backups on your mac, then combine that with the chat.db on your mac.

Add way to track indvidual messages threads that have already been imported.. Maybe. Kind of difficult since Day One 
doesn't allow me to peek in, so I have to create identifiers for each chat on a day, maybe even individual messages and then store those identifiers. 
