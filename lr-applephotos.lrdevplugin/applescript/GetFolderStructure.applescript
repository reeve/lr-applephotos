set targetFile to POSIX file "/Users/adamreeve/src/lr-applephotos/lr-applephotos.lrdevplugin/applescript/JSONlib.scpt"
set jsonLib to load script targetFile

tell application "Photos"
    set children to my recurseFolders(application "Photos")
    set tree to {{n: "Root", i: "root", c: children, t: "f"}}
    tell jsonLib
        set foo to jsonLib's convertASToJSON:tree saveTo:missing value
    end tell
    return foo
end tell

on recurseFolders(currentContainer)
	tell application "Photos"
        set folderRecords to {}
        set allSubfolders to folders of currentContainer
        set allAlbums to albums of currentContainer
        repeat with subFolder in allSubfolders
            set folderName to name of subFolder
            set folderId to id of subFolder
            set children to my recurseFolders(subFolder)

            set thisRecord to {n: folderName, i: folderId, c: children, t: "f"}
            set end of folderRecords to thisRecord
        end repeat
        repeat with thisAlbum in allAlbums
            set albumName to name of thisAlbum
            set albumId to id of thisAlbum

            set thisRecord to {n: albumName, i: albumId, t: "a"}
            set end of folderRecords to thisRecord
        end repeat
        return folderRecords
	end tell
end recurseFolders