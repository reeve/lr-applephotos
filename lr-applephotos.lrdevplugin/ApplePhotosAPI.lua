-- Import the required Lightroom SDK modules
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local logger = import 'LrLogger' ('ApplePhotosAPI'):enable("logfile")
local json = require "json"

ApplePhotosAPI = {}

local function flattenFolderTree(tree)
    logger:info("flattenFolderTree")
    local flattenedList = {}
    for _, record in ipairs(tree) do
        if record.t == "f" then
            table.insert(flattenedList, { title = record.n, value = record.i })
            if next(record.c) ~= nil then
                local children = flattenFolderTree(record.c)
                for _, child in ipairs(children) do
                    table.insert(flattenedList, { title = "--" .. child.title, value = child.value })
                end
            end
        end
    end
    return flattenedList
end

local function albumsByFolder(tree)
    logger:info("albumsByFolder")
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
                        if child.t == "f" then -- recurse into folders and merge result
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

function ApplePhotosAPI.updateFolderStructure(propertyTable)
    logger:info("updateFolderStructure")

    -- LrTasks.execute must run inside an asynchronous task context
    LrTasks.startAsyncTask(function()
        -- 1. Create a safe temporary file path for the output
        local tempOutputFile = LrFileUtils.chooseUniqueFileName(os.tmpname())
        logger:info(tempOutputFile)

        local scriptPath =
        '/Users/adamreeve/src/lr-applephotos/lr-applephotos.lrdevplugin/applescript/GetFolderStructure.applescript'

        -- 3. Construct the command line
        -- We use osascript -e to run inline text, and '>' to save output to our temp file
        local command = string.format("osascript '%s' > '%s'", scriptPath, tempOutputFile)
        logger:info(command)

        -- 4. Execute the command via Lightroom's task manager
        local resultCode = LrTasks.execute(command)
        logger:info(resultCode)

        -- Check if the command ran successfully (returns 0)
        if resultCode == 0 then
            -- 5. Read the captured string from the file
            if LrFileUtils.exists(tempOutputFile) then
                local capturedOutput = LrFileUtils.readFile(tempOutputFile)

                -- Strip trailing newlines often added by the terminal output
                capturedOutput = string.gsub(capturedOutput, "%s+$", "")

                -- Your captured string is ready!
                logger:info("AppleScript Output: " .. capturedOutput)

                local result = json.decode(capturedOutput)
                propertyTable.folderStructure = result

                local flattenedList = flattenFolderTree(result)
                propertyTable.folderList = flattenedList

                local albumMap = albumsByFolder(result)
                propertyTable.albumMap = albumMap

                -- set defaults
                if propertyTable.selectedFolder == nil then
                    propertyTable.selectedFolder = flattenedList[1].value
                end
            end
        else
            logger:error("AppleScript execution failed with code: " .. tostring(resultCode))
            propertyTable.folderStructure = nil
        end

        -- 6. Clean up by deleting the temporary file
        if LrFileUtils.exists(tempOutputFile) then
            LrFileUtils.delete(tempOutputFile)
        end
    end
    )
end

function ApplePhotosAPI.importPhoto(albumId, photoPath, propertyTable)
    -- must be called from with a task
    logger:info("importPhoto | " .. albumId .. " | " .. photoPath)

    -- LrTasks.startAsyncTask(function()
    local scriptPath =
    '/Users/adamreeve/src/lr-applephotos/lr-applephotos.lrdevplugin/applescript/ImportPhoto.applescript'

    local command = string.format("osascript '%s' '%s' '%s'", scriptPath, albumId, photoPath)
    -- local command = string.format(
    --     "osascript '%s' '4EE440C9-AA81-4A24-97D9-7028C9A75EFA/L0/040' '/var/folders/rw/lmq05c7x1jv12d6rdgd6cwjr0000gn/T/6138402085_b15bc83db8_b_edit.jpg'",
    --     scriptPath)
    logger:info(command)

    local resultCode = LrTasks.execute(command)
    logger:info(resultCode)
    -- end
    -- )
end

function ApplePhotosAPI.createFolder(albumName, folderId, propertyTable)
    -- must be called from with a task
    logger:info("createFolder | " .. albumName .. " | " .. folderId)

    local scriptPath =
    '/Users/adamreeve/src/lr-applephotos/lr-applephotos.lrdevplugin/applescript/CreateAlbum.applescript'
    local tempOutputFile = LrFileUtils.chooseUniqueFileName(os.tmpname())
    logger:info(tempOutputFile)

    local command = string.format("osascript '%s' '%s' '%s' > '%s'", scriptPath, albumName, folderId, tempOutputFile)
    logger:info(command)

    local resultCode = LrTasks.execute(command)
    logger:info(resultCode)

    if resultCode == 0 then
        -- 5. Read the captured string from the file
        if LrFileUtils.exists(tempOutputFile) then
            local capturedOutput = LrFileUtils.readFile(tempOutputFile)

            -- Strip trailing newlines often added by the terminal output
            capturedOutput = string.gsub(capturedOutput, "%s+$", "")

            -- Your captured string is ready!
            logger:info("AppleScript Output: " .. capturedOutput)

            local result = json.decode(capturedOutput)
            local newAlbumID = result.i

            return newAlbumID
        end
    end
end
