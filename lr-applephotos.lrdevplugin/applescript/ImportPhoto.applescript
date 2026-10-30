
on run argv
    tell application "Finder"
        -- Get the parent folder of the running script
        set currentDirectory to container of (path to me) as text
    end tell
    set jsonLibPath to currentDirectory & "JSONlib.scpt"
    set jsonLib to load script file jsonLibPath

    if length of argv is not 2 then
        error "invalid arguments" number 22 -- invalid argument
    end if

    set albumId to item 1 of argv
    set imagePath to item 2 of argv

    try 
        set imageAlias to (POSIX file imagePath) as alias
    on error
        error "unable to create alias" number 2 -- file not found
    end try

    tell application "Photos"
        set targetAlbum to album id albumId

        if targetAlbum is not missing value then
            try 
                set imagerecords to import imageAlias into targetAlbum with skip check duplicates
                set imagerecord to item 1 of imagerecords 
                set response to {success: true, fn: filename of imagerecord, i: id of imagerecord}
            on error
                set response to {success: false, |error|: "error during import"}
            end try
        else 
            set response to {success: false, |error|: "targetAlbum not found"}
        end

        tell jsonLib
            set jsonResponse to jsonLib's convertASToJSON:response saveTo:missing value
        end tell
    
        return jsonResponse
    end tell
end run

