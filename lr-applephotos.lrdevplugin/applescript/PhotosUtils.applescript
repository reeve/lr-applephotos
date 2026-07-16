

on locateFolderFromPath(folderPath)
	tell application "Photos"
        if folderPath is "" then
            error "folderPath cannot be empty"
        end

		set AppleScript's text item delimiters to ","
		set pathList to text items of folderPath
		set AppleScript's text item delimiters to ""
		
		set currentContainer to application "Photos"
		repeat with pathElemID in pathList
			set currentContainer to folder id pathElemID of currentContainer
		end repeat
		
		return currentContainer
	end tell
end locateFolderFromPath