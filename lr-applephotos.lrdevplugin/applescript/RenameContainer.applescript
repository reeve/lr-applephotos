-- renames an album or folder
-- parameters: <container id> <album|folder> <new name>
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

    set containerId to item 1 of argv
    set containerType to item 2 of argv
    set newName to item 3 of argv

    if containerType is not "album" and containerType is not "folder" then
        error "invalid containerType" number 1
    end if

    tell application "Photos"
        try
            if containerType is "album" then
                set existingContainer to album id containerId
            else if containerType is "folder" then
                set existingContainer to folder id containerId
            end if

            if existingContainer is not missing value then
                set name of existingContainer to newName
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

