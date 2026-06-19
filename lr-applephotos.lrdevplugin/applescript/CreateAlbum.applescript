
on run argv
    set targetFile to POSIX file "/Users/adamreeve/src/lr-applephotos/lr-applephotos.lrdevplugin/applescript/JSONlib.scpt"
    set jsonLib to load script targetFile

    if length of argv is not 2 then
        error "invalid arguments" number 1
    end if

    set albumName to item 1 of argv
    set parentFolderId to item 2 of argv

    tell application "Photos"
        -- try 
            if parentFolderId is "root" then
                set newAlbum to make new album named albumName
            else        
                set parentFolder to folder id parentFolderId
                set newAlbum to make new album named albumName at parentFolder
            end if
        -- on error
            -- error "failed to create album" number 2          
        -- end try

        set response to {n: name of newAlbum, i: id of newAlbum}
        tell jsonLib
            set jsonResponse to jsonLib's convertASToJSON:response saveTo:missing value
        end tell
        return jsonResponse
    end tell
end run

