
-- creates a new album or folder in a specified folder
-- parameters: <container name> <album|folder> <parentPath>
--      note: set <parentPath> to empty string to create album outside of all folders
on run argv
    tell application "Finder"
        -- Get the parent folder of the running script
        set currentDirectory to container of (path to me) as text
    end tell
    set jsonLibPath to currentDirectory & "JSONlib.scpt"
    set jsonLib to load script file jsonLibPath
    set utilsLibPath to currentDirectory & "PhotosUtils.scpt"
    set utilsLib to load script file utilsLibPath

    if length of argv is not 3 then
        error "invalid arguments" number 1
    end if

    set containerName to item 1 of argv
    set containerType to item 2 of argv
    set parentPath to item 3 of argv

    if containerType is not "album" and containerType is not "folder" then
        error "invalid containerType" number 1
    end if

    tell application "Photos"
        if parentPath is "" then
            if containerType is "album" then
                set newContainer to make new album named containerName
            else if containerType is "folder" then
                set newContainer to make new folder named containerName
            end
        else        
            set parentFolder to utilsLib's locateFolderFromPath(parentPath)
            if containerType is "album" then
                set newContainer to make new album named containerName at parentFolder
            else if containerType is "folder" then
                set newContainer to make new folder named containerName at parentFolder
            end
        end if

        set response to {n: name of newContainer, i: id of newContainer}
        tell jsonLib
            set jsonResponse to jsonLib's convertASToJSON:response saveTo:missing value
        end tell
        
        return jsonResponse
    end tell
end run

