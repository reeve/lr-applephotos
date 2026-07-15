-- renames a folder
-- parameters: <container id> <parentPath> <new name>
on run argv
    tell application "Finder"
        -- Get the parent folder of the running script
        set currentDirectory to container of (path to me) as text
    end tell
    set jsonLibPath to currentDirectory & "JSONlib.scpt"
    set jsonLib to load script file jsonLibPath

    if length of argv is not 3 then
        error "invalid arguments" number 1
    end if

    set folderID to item 1 of argv
    set parentPath to item 2 of argv
    set newName to item 3 of argv

    tell application "Photos"
        try
    	    set existingFolder to my findFolder(parentPath, folderID)

            if existingFolder is not missing value then
                set name of existingFolder to newName
                set response to {status: "ok"}
            else 
                set response to {status: "not found"}
            end if
        on error
            -- Likely doesn't exist
            set response to {status: "not found"}
        end try

        tell jsonLib
            set jsonResponse to jsonLib's convertASToJSON:response saveTo:missing value
        end tell
        
        return jsonResponse

    end tell
end run

on findFolder(parentPath, folderID)
	tell application "Photos"
		if parentPath is "" then
			set existingFolder to folder id folderID
			return existingFolder
		end if
		
		set AppleScript's text item delimiters to ","
		set pathList to text items of parentPath
		set AppleScript's text item delimiters to ""
		
		set currentContainer to application "Photos"
		repeat with parentID in pathList
			set parentFolder to folder id parentID of currentContainer
			set currentContainer to parentFolder
		end repeat
		
		set existingFolder to currentContainer's folder id folderID
        return existingFolder
	end tell
end findFolder