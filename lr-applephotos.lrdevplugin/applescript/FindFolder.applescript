on run argv
    tell application "Finder"
        -- Get the parent folder of the running script
        set currentDirectory to container of (path to me) as text
    end tell
    set jsonLibPath to currentDirectory & "JSONlib.scpt"
    set jsonLib to load script file jsonLibPath

    tell application "Photos"
        set targetFolderID to item 1 of argv

        set searchResult to my recurseFolders(application "Photos", "", targetFolderID)
        if searchResult is missing value then
            set response to {status: "not found", target: targetFolderID}
        else
            set response to {status: "ok", target: targetFolderID, parents: searchResult}
        end if

        tell jsonLib
            set jsonResponse to jsonLib's convertASToJSON:response saveTo:missing value
        end tell
        return jsonResponse
    end tell
end run

on recurseFolders(currentContainer, pathSoFar, targetFolderID)
	tell application "Photos"
		set allSubfolders to folders of currentContainer
		set pathElement to id of currentContainer
		if pathElement is not "com.apple.photos" then
			if pathSoFar is not "" then
				set newPath to pathSoFar & "," & pathElement
			else
				set newPath to pathElement
			end if
		else
			set newPath to pathSoFar
		end if
		repeat with subFolder in allSubfolders
			set folderId to id of subFolder
			if folderId is targetFolderID then
				return newPath
			end if
			
			set response to my recurseFolders(subFolder, newPath, targetFolderID)
			if response is not missing value then
				return response
			end if
		end repeat
		return missing value
	end tell
end recurseFolders
