
-- creates a new album in a specified folder
-- parameters: <album name> <folder id>
--      note: set <folder id> to special value "root" to create album outside of all folders
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

    set albumName to item 1 of argv
    set parentFolderId to item 2 of argv

    tell application "Photos"
        if parentFolderId is "root" then
            set newAlbum to make new album named albumName
        else        
            set parentFolder to folder id parentFolderId
            set newAlbum to make new album named albumName at parentFolder
        end if

        set response to {n: name of newAlbum, i: id of newAlbum}
        tell jsonLib
            set jsonResponse to jsonLib's convertASToJSON:response saveTo:missing value
        end tell
        
        return jsonResponse
    end tell
end run

