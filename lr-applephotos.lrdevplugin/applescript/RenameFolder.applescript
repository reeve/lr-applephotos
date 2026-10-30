-- renames a folder
-- parameters: <folderPath> <new name>
on run argv
    tell application "Finder"
        -- Get the parent folder of the running script
        set currentDirectory to container of (path to me) as text
    end tell
    set jsonLibPath to currentDirectory & "JSONlib.scpt"
    set jsonLib to load script file jsonLibPath
    set utilsLibPath to currentDirectory & "PhotosUtils.scpt"
    set utilsLib to load script file utilsLibPath

    if length of argv is not 2 then
        error "invalid arguments" number 22 -- invalid argument
    end if

    set folderPath to item 1 of argv
    set newName to item 2 of argv

    tell application "Photos"
        try
    	    set existingFolder to utilsLib's locateFolderFromPath(folderPath)

            if existingFolder is not missing value then
                set name of existingFolder to newName
                set response to {success: true}
            else 
                set response to {success: false, |error|: "folderPath not found"}
            end if
        on error
            set response to {success: false, |error|: "error during rename"}
        end try

        tell jsonLib
            set jsonResponse to jsonLib's convertASToJSON:response saveTo:missing value
        end tell
        
        return jsonResponse

    end tell
end run

