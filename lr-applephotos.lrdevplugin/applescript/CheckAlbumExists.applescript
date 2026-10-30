
-- checks whether an album exists, and returns it's name if so
-- parameters: <album id> <optional root folder id>
on run argv
    tell application "Finder"
        -- Get the parent folder of the running script
        set currentDirectory to container of (path to me) as text
    end tell
    set jsonLibPath to currentDirectory & "JSONlib.scpt"
    set jsonLib to load script file jsonLibPath

    if length of argv is less than 1 or length of argv is greater than 2 then
        error "invalid arguments" number 22 -- invalid argument
    end if

    set albumId to item 1 of argv
    if length of argv is 2 then 
        set rootFolderId to item 2 of argv
    end if


    tell application "Photos"
        try
            set existingAlbum to album id albumId
            if existingAlbum is not missing value then
                set response to {n: name of existingAlbum, i: id of existingAlbum, success: true}
                if rootFolderId is not missing value then
                    set found to false
                    set p to a reference to (parent of existingAlbum)
                    repeat until p is missing value
                        if id of p is rootFolderId then
                            set found to true
                            exit
                        end if
                        set p to a reference to (parent of p)
                    end repeat
                    if not found
                        -- specified root not found in parent hierarchy, treat as not found
                        set response to {success: false, error: "found, but not a child of specified root folder"}
                    end if
                end if
            else 
                set response to {success: false, error: "not found"}
            end if
        on error
            -- Likely doesn't exist
                set response to {success: false, error: "unknown"}
        end try

        tell jsonLib
            set jsonResponse to jsonLib's convertASToJSON:response saveTo:missing value
        end tell
        
        return jsonResponse
    end tell
end run

