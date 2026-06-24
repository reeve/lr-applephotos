------
-- Simple wrapper for various interaction functions with Photos.
-- Uses custom applescript files which write output into temp json files.

local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local logger = import 'LrLogger' ('ApplePhotosAPI'):enable("logfile")
local json = require "json"

local PLUGIN_PATH = _PLUGIN.path

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

------
-- Runs an applescript file and captures the output, parsing it as json and returning the result code and response data structrue as a tuple.
-- Returns negative result code if the invocation mechanism failed (vs positive result code for error reported by applescript)
local function invokeScript(scriptName, ...)
    local scriptPath = LrPathUtils.standardizePath(LrPathUtils.addExtension(
        LrPathUtils.child(LrPathUtils.child(PLUGIN_PATH, "applescript"), scriptName), "applescript"))

    if not LrFileUtils.isReadable(scriptPath) then
        logger.error("Applescript file [" .. scriptPath .. "] is not existent/readable")
        return -1, nil
    end

    local tempOutputFile = LrFileUtils.chooseUniqueFileName(LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'),
        "tmp-" .. scriptName))

    -- Build and execute the command line with osascript
    local args = table.concat({ ... }, "' '")
    if args ~= "" then
        args = "'" .. args .. "'"
    end
    local command = string.format("osascript '%s' %s > '%s'", scriptPath, args, tempOutputFile)
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
        logger:error("AppleScript execution failed with code: " .. tostring(resultCode))
    end

    if LrFileUtils.exists(tempOutputFile) then
        LrFileUtils.delete(tempOutputFile)
    end

    return resultCode, result
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
function ApplePhotosAPI.importPhoto(albumId, photoPath, propertyTable)
    -- must be called from with a task
    logger:info("importPhoto | " .. albumId .. " | " .. photoPath)

    local resultCode, result = invokeScript("ImportPhoto", albumId, photoPath)

    if resultCode == 0 and result ~= nil then
        local newImageID = result.i
        return newImageID
    else
        logger:error("Error importing image: " .. resultCode)
        return nil
    end
end

------
-- Creates a new Album in the Photos hierachy. Name is (seemingly) any string, folderId should have previously been obtained via queryFolderStructure().
function ApplePhotosAPI.createAlbum(albumName, folderId, propertyTable)
    -- must be called from with a task
    logger:info("createAlbum | " .. albumName .. " | " .. folderId)

    local resultCode, result = invokeScript("CreateAlbum", albumName, folderId)

    if resultCode == 0 and result ~= nil then
        local newAlbumID = result.i
        return newAlbumID
    else
        logger:error("Error creating new album: " .. resultCode)
        return nil
    end
end
