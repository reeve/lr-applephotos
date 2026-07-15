-- renames an album
-- parameters: <album id> <new name>
on run argv
    tell application "Finder"
        -- Get the parent folder of the running script
        set currentDirectory to container of (path to me) as text
    end tell
    set jsonLibPath to currentDirectory & "JSONlib.scpt"
    set jsonLib to load script file jsonLibPath

    if length of argv is not 2 then
        error "invalid arguments" number 1
    end if

    set albumID to item 1 of argv
    set newName to item 2 of argv

    tell application "Photos"
        try
            -- this doesn't work for folders, which is why it's a different rename script
            set existingAlbum to album id albumID

            if existingAlbum is not missing value then
                set name of existingAlbum to newName
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

