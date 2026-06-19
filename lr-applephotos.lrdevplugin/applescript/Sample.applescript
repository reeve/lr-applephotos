tell application "Finder"
	activate
	-- Prompt the user to select a folder
	set theFolder to (choose folder with prompt "Select a folder to import into Photos:")
	set albumName to name of theFolder
	
	-- Gather all files inside the chosen folder
	set fileList to files of theFolder
	set imageAliases to {}
	
	-- Convert the files to alias formats that the Photos app expects
	repeat with aFile in fileList
		set end of imageAliases to (aFile as alias)
	end repeat
end tell

tell application "Photos"
	activate
	
	set foundFolder to my findFolderInPhotos("Model Shoots", application "Photos")
	if foundFolder is missing value then
		error "Can't find base folder" number 1
	end if
	
	-- Check if the album already exists, if not, create it
	set matchingAlbums to (albums of foundFolder whose name is albumName)
	if (count of matchingAlbums) is 0 then
		set targetAlbum to make new album named albumName at foundFolder
	else
		set targetAlbum to first item of matchingAlbums
	end if
	
	-- Import the images directly into that specific album
	import imageAliases into targetAlbum without skip check duplicates
end tell

-- Recursive helper handler
on findFolderInPhotos(targetName, currentContainer)
	tell application "Photos"
		-- Check if the folder exists at the current level
		set matchingFolders to (folders of currentContainer whose name is targetName)
		if (count of matchingFolders) > 0 then
			return first item of matchingFolders
		end if
		
		-- If not found, look deeper into subfolders
		set allSubfolders to folders of currentContainer
		repeat with subFolder in allSubfolders
			set deepMatch to my findFolderInPhotos(targetName, subFolder)
			if deepMatch is not missing value then
				return deepMatch
			end if
		end repeat
		
		return missing value
	end tell
end findFolderInPhotos
