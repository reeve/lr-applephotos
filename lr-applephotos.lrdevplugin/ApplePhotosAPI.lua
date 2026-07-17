------
-- Simple wrapper for various interaction functions with Photos.
-- Uses custom applescript files which write output into temp json files.

local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local logger = import 'LrLogger' ('ApplePhotosAPI'):enable("logfile")
local json = require "json"

local PLUGIN_PATH = _PLUGIN.path

local SWIFT_BIN_NAME = "PhotosProxyApp.app"

ApplePhotosAPI = {}

-- TODO: move this view specific logic into the view class?
-- recursively turn the folder/album tree structure into a flat list of folder names (using blank string prefixes to attempt indentation)
-- used to populate folder picker dropdown
local function flattenFolderTree(tree)
    local flattenedList = {}
    for _, record in ipairs(tree) do
        if record.t == "f" then
            table.insert(flattenedList, { title = record.n, value = record.i })
            if next(record.c) ~= nil then
                local children = flattenFolderTree(record.c)
                for _, child in ipairs(children) do
                    table.insert(flattenedList, { title = "  " .. child.title, value = child.value })
                end
            end
        end
    end
    return flattenedList
end

-- recursively turn the folder/album tree structure into a flat map of <folderID> -> <list of contained albumIDs>
-- used to know which albums to display for selection based on selected folder
local function albumsByFolder(tree)
    local flattenedMap = {}
    for _, record in ipairs(tree) do -- for each entry at this level
        if record.t == "f" then      -- if it's a folder
            local albums = {}
            if next(record.c) ~= nil then
                local children = record.c
                for _, child in ipairs(children) do -- for each child
                    if child.t == "a" then          -- collect albums
                        table.insert(albums, { title = child.n, value = child.i })
                    else
                        if child.t == "f" then -- recurse into folders and merge deeper results into this level
                            local recurseResult = albumsByFolder({ child })
                            for key, value in pairs(recurseResult) do
                                flattenedMap[key] = value
                            end
                        end
                    end
                end

                flattenedMap[record.i] = albums -- set album list as entry for this item
            end
        end
    end
    return flattenedMap
end

local function genericInvoke(name, commandFormatter)
    local tempOutputFile = LrFileUtils.chooseUniqueFileName(LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'),
        "tmp-" .. name))

    local command = commandFormatter(name, tempOutputFile)

    logger:info("Invoking command: " .. command)
    local resultCode = LrTasks.execute(command)
    local result = nil

    if resultCode == 0 then
        if LrFileUtils.exists(tempOutputFile) then
            local capturedOutput = LrFileUtils.readFile(tempOutputFile)

            -- Strip trailing newlines often added by the terminal output
            capturedOutput = string.gsub(capturedOutput, "%s+$", "")

            -- Decode JSON
            result = json.decode(capturedOutput)
        end
    else
        logger:error("Command execution failed with code: " .. tostring(resultCode))
    end

    if LrFileUtils.exists(tempOutputFile) then
        LrFileUtils.delete(tempOutputFile)
    end

    return resultCode, result
end

------
-- Runs an applescript file and captures the output, parsing it as json and returning the result code and response data structrue as a tuple.
-- Returns negative result code if the invocation mechanism failed (vs positive result code for error reported by applescript)
local function invokeScript(scriptName, ...)
    local scriptPath = LrPathUtils.standardizePath(LrPathUtils.addExtension(
        LrPathUtils.child(LrPathUtils.child(PLUGIN_PATH, "applescript"), scriptName), "applescript"))

    if not LrFileUtils.isReadable(scriptPath) then
        logger:error("Applescript file [" .. scriptPath .. "] is not existent/readable")
        return -1, nil
    end

    local args = table.concat({ ... }, "' '")
    if args ~= "" then
        args = "'" .. args .. "'"
    end

    return genericInvoke(scriptName, function(_, tempOutputFile)
        return string.format("osascript '%s' %s > %s", scriptPath, args, tempOutputFile)
    end)
end

local function invokeSwift(command, ...)
    local binPath = LrPathUtils.child(
        "/Users/adamreeve/Library/Developer/Xcode/DerivedData/PhotosProxyApp-eezaswzlqeohwtcyotixthdhhjdm/Build/Products/Debug",
        SWIFT_BIN_NAME)

    if not LrFileUtils.isReadable(binPath) then
        logger:error("Swift helper file [" .. binPath .. "] is not existent/readable")
        return -1, nil
    end

    local args = table.concat({ ... }, "' '")
    if args ~= "" then
        args = "'" .. args .. "'"
    end

    return genericInvoke(command, function(_, tempOutputFile)
        return string.format("open -n -W --stdout %s --stderr %s -a %s --args %s --json-response %s", tempOutputFile,
            tempOutputFile, binPath, command, args)
    end)
end

local function array_difference(array1, array2)
    local lookup = {}
    local diff = {}

    -- Map elements of array2 as keys for fast O(1) lookups
    for _, value in ipairs(array2) do
        lookup[value] = true
    end

    -- Check if elements from array1 are missing in array2
    for _, value in ipairs(array1) do
        if not lookup[value] then
            table.insert(diff, value)
        end
    end

    return diff
end

------
-- Query the folder structure from Photos and write it into the local context. Gets all folders and albums currently defined.
function ApplePhotosAPI.queryFolderStructure(propertyTable)
    logger:info("updateFolderStructure")

    propertyTable.scanningFolders = true

    LrTasks.startAsyncTask(function()
        local resultCode, result = invokeScript("GetFolderStructure")

        -- Check if the command ran successfully (returns 0)
        if resultCode == 0 then
            propertyTable.folderStructure = result

            local flattenedList = flattenFolderTree(result)
            propertyTable.folderList = flattenedList

            local albumMap = albumsByFolder(result)
            propertyTable.albumMap = albumMap

            -- set defaults
            if propertyTable.selectedFolder == nil then
                propertyTable.selectedFolder = flattenedList[1].value
            end
        else
            logger:error("Error querying folder structure: " .. resultCode)
            propertyTable.folderStructure = nil
        end

        propertyTable.scanningFolders = false
    end
    )
end

------
-- Imports a single photo. Takes the albumId to add it to, and the path of the image to import.
function ApplePhotosAPI.importPhoto(albumId, photoPath)
    -- must be called from with a task
    logger:info("importPhoto | " .. albumId .. " | " .. photoPath)

    local resultCode, result = invokeScript("ImportPhoto", albumId, photoPath)

    if resultCode == 0 and result ~= nil and next(result) ~= nil then
        local newImageID = result.i
        return newImageID
    else
        logger:error("Error importing image: " .. resultCode)
        return nil
    end
end

------
-- Creates a new Album in the Photos hierachy. Name is (seemingly) any string, folderID should have previously been obtained via queryFolderStructure().
function ApplePhotosAPI.createAlbum(albumName, folderID)
    -- must be called from with a task
    logger:info("createAlbum | " .. albumName .. " | " .. folderID)

    local parentPath = ""
    if folderID ~= "root" then
        local searchResult = ApplePhotosAPI.findFolder(folderID)
        if searchResult == nil then
            logger:error("Can't find base folder")
            return nil
        end
        parentPath = searchResult
    end

    local resultCode, result = invokeScript("CreateContainer", albumName, "album", parentPath)

    if resultCode == 0 and result ~= nil and next(result) ~= nil then
        local newAlbumID = result.i
        return newAlbumID
    else
        logger:error("Error creating new album: " .. resultCode)
        return nil
    end
end

------
-- Creates a new Folder in the Photos hierachy. Name is (seemingly) any string, folderID should have previously been obtained via queryFolderStructure().
function ApplePhotosAPI.createFolder(folderName, folderID)
    -- must be called from with a task
    logger:info("createFolder | " .. folderName .. " | " .. folderID)

    local parentPath = ""
    if folderID ~= "root" then
        local searchResult = ApplePhotosAPI.findFolder(folderID)
        if searchResult == nil then
            logger:error("Can't find base folder")
            return nil
        end
        parentPath = searchResult
    end
    local resultCode, result = invokeScript("CreateContainer", folderName, "folder", parentPath)

    if resultCode == 0 and result ~= nil and next(result) ~= nil then
        local newFolderID = result.i
        return newFolderID
    else
        logger:error("Error creating new folder: " .. resultCode)
        return nil
    end
end

------
-- Checks for existance of an album by it's ID. If existant, returns the current name. If not, returns false.
function ApplePhotosAPI.checkAlbumExists(albumID)
    -- must be called from with a task
    logger:info("checkAlbumExists | " .. albumID)

    local resultCode, result = invokeScript("CheckAlbumExists", albumID)

    if resultCode == 0 and result ~= nil and next(result) ~= nil then
        local currentAlbumName = result.n
        return currentAlbumName
    else
        return false
    end
end

------
-- Deletes images, referenced by their ID. The image will be deleted from the library entirely, regardless of which albums it is in.
-- Returns a list of the IDs successfully deleted.
-- NOTE: Photos will prompt the user for confirmation on each execution, this is unavoidable.
function ApplePhotosAPI.deleteImages(imageIDs)
    -- must be called from with a task
    logger:info("deleteImages | " .. table.concat(imageIDs, " "))

    local resultCode, result = invokeSwift("delete", unpack(imageIDs))

    if resultCode == 0 and result ~= nil and result.success then
        -- all good, just figure out missing files
        local deleted = array_difference(imageIDs, result.missingIDs)
        logger:info("Deleted: " .. table.concat(deleted, " "))
        return deleted
    elseif result ~= nil and result.error ~= nil then
        logger:error("Error deleting images: " .. result.error)
    else
        logger:error("Unknown error")
    end

    return {}
end

------
-- Renames a given album. Returns boolean success flag.
function ApplePhotosAPI.renameAlbum(albumID, newName)
    -- must be called from with a task
    logger:info("renameAlbum | " .. albumID .. " | " .. newName)

    local resultCode, result = invokeScript("RenameAlbum", albumID, newName)

    if resultCode == 0 and result ~= nil and result.status == "ok" then
        return true
    elseif result ~= nil then
        logger:error("Error renaming album: " .. result.status)
    else
        logger:error("Unknown error")
    end

    return false
end

------
-- Renames a given folder. Returns boolean success flag.
function ApplePhotosAPI.renameFolder(folderID, newName)
    -- must be called from with a task
    logger:info("renameFolder | " .. folderID .. " | " .. newName)

    local folderPath = ""
    if folderID ~= "root" then
        local searchResult = ApplePhotosAPI.findFolder(folderID)
        if searchResult == nil then
            logger:error("Can't find folder to rename")
            return nil
        end
        folderPath = searchResult
    end
    local resultCode, result = invokeScript("RenameFolder", folderPath, newName)

    if resultCode == 0 and result ~= nil and result.status == "ok" then
        return true
    elseif result ~= nil then
        logger:error("Error renaming folder: " .. result.status)
    else
        logger:error("Unknown error")
    end

    return false
end

------
-- Finds the path to a given folder. Returns the path as a comma seperated list of ancestors (from furthest to nearest) including the target itself.
-- Nil result indicates not found.
function ApplePhotosAPI.findFolder(folderID)
    -- must be called from with a task
    logger:info("findFolder | " .. folderID)

    local resultCode, result = invokeScript("FindFolder", folderID)

    if resultCode == 0 and result ~= nil and result.status == "ok" then
        return result.path
    elseif result ~= nil then
        logger:error("Error searching for folder: " .. result.status)
    else
        logger:error("Unknown error")
    end

    return nil
end

function ApplePhotosAPI.deleteFolder(folderID)
    -- must be called from with a task
    logger:info("deleteFolder | " .. folderID)

    if folderID == "root" then
        error("invalid folderID: " .. folderID)
    end

    local searchResult = ApplePhotosAPI.findFolder(folderID)
    if searchResult == nil then
        logger:error("Can't find folder to delete")
        return nil
    end
    local folderPath = searchResult

    local resultCode, result = invokeScript("DeleteFolder", folderPath)

    if resultCode == 0 and result ~= nil and result.status == "ok" then
        return true
    elseif result ~= nil then
        logger:error("Error deleting folder: " .. result.status)
    else
        logger:error("Unknown error")
    end

    return false
end
