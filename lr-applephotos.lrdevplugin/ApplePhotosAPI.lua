------
-- Simple wrapper for various interaction functions with Photos.
-- Uses custom applescript files which write output into temp json files.

local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local logger = import 'LrLogger' ('ApplePhotosAPI'):enable("logfile")
local json = require "json"
local utils = require "utils"

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

--- Generic utility to invoke some command and handle the response.
-- Takes a command name (assumed to be a simple string) and a function which generate the full command line.
-- The formatter must also accept a filename to direct output to. Any non-zero exit code will result in an error being thrown.
-- The output of the command must follow the following conventions to work via this mechanism:
--   * Strict JSON formatting
--   * success: [true|false]
--   * error: [string, optional]
-- @param name the command name (e.g. "import-image")
-- @param commandFormatter function which takes a filename for output, and returns the complete command string
-- @return boolean success flag
-- @return a table parsed from the command's output
local function genericInvoke(name, commandFormatter)
    local tempOutputFile = LrFileUtils.chooseUniqueFileName(LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'),
        "tmp-" .. name))

    local command = commandFormatter(tempOutputFile)

    logger:debug("Invoking shell command: " .. command)
    local resultCode = LrTasks.execute(command)
    local result = nil
    if resultCode == 0 then
        if LrFileUtils.exists(tempOutputFile) then
            local capturedOutput = LrFileUtils.readFile(tempOutputFile)

            -- delete file now in case anything bad happens :)
            if LrFileUtils.exists(tempOutputFile) then
                LrFileUtils.delete(tempOutputFile)
            end

            -- Strip trailing newlines often added by the terminal output
            capturedOutput = string.gsub(capturedOutput, "%s+$", "")

            -- Decode JSON
            result = json.decode(capturedOutput)

            if utils.nilOrEmpty(result) then
                utils.logAndFail(logger, "Invalid or empty response from command: " .. capturedOutput)
            end

            local success = result.success
            if not success then
                logger:error("Script reported error, continuing: " .. utils.withDefault(result.error, "unknown error"))
            end

            logger:debug("Completed execution of command: " .. name)
            return success, result
        else
            utils.logAndFail(logger, "Unable to read output file: " .. tempOutputFile)
        end
    else
        if LrFileUtils.exists(tempOutputFile) then
            LrFileUtils.delete(tempOutputFile)
        end

        utils.logAndFail(logger, "Command execution failed with code: " .. tostring(resultCode))
    end
end

--- Runs a specified applescript helper with the supplied parameters.
-- @param scriptName the command name, without any path or file extension (e.g. "FindFolder")
-- @param ... parameters to pass to the command
-- @return boolean success flag
-- @return a table containing the returned data from the command
local function invokeScript(scriptName, ...)
    -- find script file
    local scriptPath = LrPathUtils.standardizePath(LrPathUtils.addExtension(
        LrPathUtils.child(LrPathUtils.child(PLUGIN_PATH, "applescript"), scriptName), "applescript"))

    if not LrFileUtils.isReadable(scriptPath) then
        utils.logAndFail(logger, "Applescript file [" .. scriptPath .. "] is not existent/readable")
    end

    -- build params
    local args = table.concat({ ... }, "' '")
    if args ~= "" then
        args = "'" .. args .. "'"
    end

    return genericInvoke(scriptName, function(tempOutputFile)
        -- execute via osascript, redirect to output file
        return string.format("osascript '%s' %s > %s", scriptPath, args, tempOutputFile)
    end)
end

--- Runs the binary (swift) helper for a specific command, with the supplied parameters.
-- @param command the command name (e.g. "delete-folder")
-- @param ... parameters to pass to the command
-- @return boolean success flag
-- @return a table containing the returned data from the command
local function invokeSwift(command, ...)
    local binPath = LrPathUtils.child(
        "/Users/adamreeve/Library/Developer/Xcode/DerivedData/PhotosProxyApp-eezaswzlqeohwtcyotixthdhhjdm/Build/Products/Debug",
        SWIFT_BIN_NAME)

    if not LrFileUtils.isReadable(binPath) then
        utils.logAndFail(logger, "Binary helper executable file [" .. binPath .. "] is not existent/readable")
    end

    -- build params
    local args = table.concat({ ... }, "' '")
    if args ~= "" then
        args = "'" .. args .. "'"
    end

    return genericInvoke(command, function(tempOutputFile)
        -- execute binary helper, redirecting stdout/stderr and passing args
        return string.format("open -n -W --stdout %s --stderr %s -a %s --args %s --json-response %s", tempOutputFile,
            tempOutputFile, binPath, command, args)
    end)
end

------
-- START OF API METHODS

------
-- Query the folder structure from Photos and write it into the local context. Gets all folders and albums currently defined.
function ApplePhotosAPI.queryFolderStructure(propertyTable)
    logger:info(">> updateFolderStructure")

    propertyTable.scanningFolders = true

    LrTasks.startAsyncTask(function()
        local success, result = invokeScript("GetFolderStructure")

        if success then
            local folderStructure = result.structure

            propertyTable.folderStructure = folderStructure

            local flattenedList = flattenFolderTree(folderStructure)
            propertyTable.folderList = flattenedList

            local albumMap = albumsByFolder(folderStructure)
            propertyTable.albumMap = albumMap

            -- set defaults
            if propertyTable.selectedFolder == nil or not utils.array_contains_property(flattenedList, "value", propertyTable.selectedFolder) then
                propertyTable.selectedFolder = flattenedList[1].value
            end
        else
            logger:error("Error querying folder structure: " .. utils.withDefault(result.error, "unknown"))
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
    logger:info(">> importPhoto | " .. albumId .. " | " .. photoPath)

    local success, result = invokeScript("ImportPhoto", albumId, photoPath)

    if success then
        local newImageID = result.i
        return newImageID
    else
        logger:error("Error importing image: " .. utils.withDefault(result.error, "unknown"))
        return nil
    end
end

------
-- Creates a new Album in the Photos hierachy. Name is (seemingly) any string, folderID should have previously been obtained via queryFolderStructure().
function ApplePhotosAPI.createAlbum(albumName, folderID)
    -- must be called from with a task
    logger:info(">> createAlbum | " .. albumName .. " | " .. folderID)

    local parentPath = ""
    if folderID ~= "root" then
        local searchResult = ApplePhotosAPI.findFolder(folderID)
        if searchResult == nil then
            logger:error("Can't find base folder")
            return nil
        end
        parentPath = table.concat(searchResult, ',')
    end

    local success, result = invokeScript("CreateContainer", albumName, "album", parentPath)

    if success then
        local newAlbumID = result.i
        return newAlbumID
    else
        logger:error("Error creating new album: " .. utils.withDefault(result.error, "unknown"))
        return nil
    end
end

------
-- Creates a new Folder in the Photos hierachy. Name is (seemingly) any string, folderID should have previously been obtained via queryFolderStructure().
function ApplePhotosAPI.createFolder(folderName, folderID)
    -- must be called from with a task
    logger:info(">> createFolder | " .. folderName .. " | " .. folderID)

    local parentPath = ""
    if folderID ~= "root" then
        local searchResult = ApplePhotosAPI.findFolder(folderID)
        if searchResult == nil then
            logger:error("Can't find base folder")
            return nil
        end
        parentPath = table.concat(searchResult, ',')
    end
    local success, result = invokeScript("CreateContainer", folderName, "folder", parentPath)

    if success then
        local newFolderID = result.i
        return newFolderID
    else
        logger:error("Error creating new folder: " .. utils.withDefault(result.error, "unknown"))
        return nil
    end
end

------
-- Checks for existence of an album by it's ID. Optionally filters to the tree branch rooted in rootFolderID.
-- If found, returns the current name. If not, returns false.
function ApplePhotosAPI.checkAlbumExists(albumID, rootFolderID)
    -- must be called from with a task
    logger:info(">> checkAlbumExists | " .. albumID .. " | " .. (rootFolderID or "nil"))

    local success, result = invokeScript("CheckAlbumExists", albumID, rootFolderID)

    if success then
        local currentAlbumName = result.n
        return currentAlbumName
    else
        return false
    end
end

------
-- Deletes images, referenced by their ID. The image will be deleted from the library entirely, regardless of which albums it is in.
-- Returns a list of the IDs successfully deleted.
-- NOTE: Photos will prompt the user for confirmation once per execution, this is unavoidable.
function ApplePhotosAPI.deleteImages(imageIDs)
    -- must be called from with a task
    logger:info(">> deleteImages | " .. table.concat(imageIDs, " "))

    local success, result = invokeSwift("delete-images", unpack(imageIDs))

    if success then
        -- all good, just figure out missing files
        local deleted = utils.array_difference(imageIDs, result.missingIDs)
        logger:info("Deleted: " .. table.concat(deleted, " "))
        return deleted
    else
        logger:error("Error deleting images: " .. utils.withDefault(result.error, "unknown"))
    end

    return {}
end

------
-- Renames a given album. Returns boolean success flag.
function ApplePhotosAPI.renameAlbum(albumID, newName)
    -- must be called from with a task
    logger:info(">> renameAlbum | " .. albumID .. " | " .. newName)

    local success, result = invokeScript("RenameAlbum", albumID, newName)

    if success then
        return true
    else
        logger:error("Error renaming album: " .. utils.withDefault(result.error, "unknown"))
    end

    return false
end

------
-- Renames a given folder. Returns boolean success flag.
function ApplePhotosAPI.renameFolder(folderID, newName)
    -- must be called from with a task
    logger:info(">> renameFolder | " .. folderID .. " | " .. newName)

    local folderPath = ""
    if folderID ~= "root" then
        local searchResult = ApplePhotosAPI.findFolder(folderID)
        if searchResult == nil then
            logger:error("Can't find folder to rename")
            return nil
        end
        folderPath = table.concat(searchResult, ',')
    end
    local success, result = invokeScript("RenameFolder", folderPath, newName)

    if success then
        return true
    else
        logger:error("Error renaming folder: " .. utils.withDefault(result.error, "unknown"))
    end

    return false
end

------
-- Finds the path to a given folder. Returns the path as an array of ancestors (from furthest to nearest) including the target itself.
-- Nil result indicates not found.
function ApplePhotosAPI.findFolder(folderID)
    -- must be called from with a task
    logger:info(">> findFolder | " .. folderID)

    local success, result = invokeScript("FindFolder", folderID)

    if success then
        return result.path
    else
        logger:error("Error searching for folder: " .. utils.withDefault(result.error, "unknown"))
    end

    return nil
end

------
-- Deletes the specified folder and any subfolders/albums. No images are affected (if not already deleted they will be orphaned).
-- @return true if successful
function ApplePhotosAPI.deleteFolder(folderID)
    -- must be called from with a task
    logger:info(">> deleteFolder | " .. folderID)

    if folderID == "root" then
        error("Invalid folderID: " .. folderID)
    end

    local success, result = invokeSwift("delete-folder", folderID)

    if success then
        return true
    else
        logger:error("Error deleting folder: " .. utils.withDefault(result.error, "unknown"))
    end

    return false
end

------
-- Deletes the specified album. No images are affected (if not already deleted they will be orphaned).
-- @return true if successful
function ApplePhotosAPI.deleteAlbum(albumID)
    -- must be called from with a task
    logger:info(">> deleteAlbum | " .. albumID)

    local success, result = invokeScript("DeleteAlbum", albumID)

    if success then
        logger:info("deleted album successfully")
        return true
    else
        logger:error("Error deleting album: " .. utils.withDefault(result.error, "unknown"))
    end

    return false
end

------
-- Moves the specified collection (and anything it contains) to a new location in the tree.
-- @return true if successful
function ApplePhotosAPI.moveCollection(collectionID, parentID)
    -- must be called from within a task
    logger:info(">> moveCollection | " .. collectionID .. " | " .. parentID)

    local success, result = invokeSwift("move", collectionID, parentID)

    if success then
        return true
    else
        logger:error("Error moving item: " .. utils.withDefault(result.error, "unknown"))
        return false
    end
end

------
-- Asks PhotosApp to display the specified photo full size.
-- @return true if successful
function ApplePhotosAPI.displayPhoto(photoID)
    -- must be called from within a task
    logger:info(">> displayPhoto | " .. photoID)

    local success, result = invokeScript("GotoPhoto", photoID)

    if success then
        return true
    else
        logger:error("Error displaying photo: " .. utils.withDefault(result.error, "unknown"))
        return false
    end
end

------
-- Asks PhotosApp to display the specified album.
-- @return true if successful
function ApplePhotosAPI.displayAlbum(albumID)
    -- must be called from within a task
    logger:info(">> displayAlbum | " .. albumID)

    local success, result = invokeScript("GotoAlbum", albumID)

    if success then
        return true
    else
        logger:error("Error displaying album: " .. utils.withDefault(result.error, "unknown"))
        return false
    end
end
