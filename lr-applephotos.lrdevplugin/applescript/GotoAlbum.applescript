-- opens the album specified in the photos UI
-- parameters: <album id>

on run argv
    tell application "Finder"
        -- Get the parent folder of the running script
        set currentDirectory to container of (path to me) as text
    end tell
    set jsonLibPath to currentDirectory & "JSONlib.scpt"
    set jsonLib to load script file jsonLibPath

    if length of argv is not 1 then
        error "invalid arguments" number 22 -- invalid argument
    end if

    set albumID to item 1 of argv

    tell application "Photos"
        try
        	set targetAlbum to album id albumID

            if targetAlbum is not missing value then
            	spotlight targetAlbum
                set response to {success: true}
            else 
                set response to {success: false, |error|: "not found"}
            end if
        on error
            set response to {success: false, |error|: "error thrown trying to spotlight"}
        end try

        tell jsonLib
            set jsonResponse to jsonLib's convertASToJSON:response saveTo:missing value
        end tell
        
        return jsonResponse
    end tell
end run
