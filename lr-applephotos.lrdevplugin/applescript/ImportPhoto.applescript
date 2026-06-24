-- set targetFile to POSIX file "/Users/adamreeve/src/lr-applephotos/lr-applephotos.lrdevplugin/applescript/JSONlib.scpt"
-- set jsonLib to load script targetFile

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

    set albumId to item 1 of argv
    set imagePath to item 2 of argv

    try 
        set imageAlias to (POSIX file imagePath) as alias
    on error
        error "unable to create alias" number 4
    end try

    tell application "Photos"
        try 
            set targetAlbum to album id albumId
        on error
            error "album not found" number 2          
        end try

        set imagerecords to import imageAlias into targetAlbum with skip check duplicates
        set imagerecord to item 1 of imagerecords 
        set response to {fn: filename of imagerecord, i: id of imagerecord}
        tell jsonLib
            set jsonResponse to jsonLib's convertASToJSON:response saveTo:missing value
        end tell
    
        return jsonResponse
    end tell
end run

