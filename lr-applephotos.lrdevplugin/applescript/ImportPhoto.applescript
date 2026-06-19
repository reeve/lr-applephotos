-- set targetFile to POSIX file "/Users/adamreeve/src/lr-applephotos/lr-applephotos.lrdevplugin/applescript/JSONlib.scpt"
-- set jsonLib to load script targetFile

on run argv
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

        try 
            import imageAlias into targetAlbum with skip check duplicates
        on error
            error "error during import" number 3        
        end try
    end tell
end run

