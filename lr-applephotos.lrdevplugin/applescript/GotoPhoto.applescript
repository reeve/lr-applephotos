-- opens the photo specified in the photos UI
-- parameters: <photo id>

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

    set photoID to item 1 of argv

    tell application "Photos"
        try
        	set targetItem to media item id photoID

            if targetItem is not missing value then
            	spotlight targetItem
                set response to {status: "ok"}
            else 
                set response to {status: "not found"}
            end if
        on error
            -- Likely doesn't exist
            set response to {status: "error"}
        end try

        tell jsonLib
            set jsonResponse to jsonLib's convertASToJSON:response saveTo:missing value
        end tell
        
        return jsonResponse
    end tell
end run
