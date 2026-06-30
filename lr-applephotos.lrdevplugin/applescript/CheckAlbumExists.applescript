
-- checks whether an album exists, and returns it's name if so
-- parameters: <album id>
on run argv
    tell application "Finder"
        -- Get the parent folder of the running script
        set currentDirectory to container of (path to me) as text
    end tell
    set jsonLibPath to currentDirectory & "JSONlib.scpt"
    set jsonLib to load script file jsonLibPath

    if length of argv is not 1 then
        error "invalid arguments" number 1
    end if

    set albumId to item 1 of argv

    tell application "Photos"
        try
            set existingAlbum to album id albumId
            if existingAlbum is not missing value then
                set response to {n: name of existingAlbum, i: id of existingAlbum}
            else 
                set response to {}
            end if
        on error
            -- Likely doesn't exist
            set response to {}
        end try

        tell jsonLib
            set jsonResponse to jsonLib's convertASToJSON:response saveTo:missing value
        end tell
        
        return jsonResponse
    end tell
end run

