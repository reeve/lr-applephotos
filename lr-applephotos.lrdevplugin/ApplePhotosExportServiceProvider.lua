require 'ApplePhotosAPI'

local LrBinding = import 'LrBinding'
local LrView = import 'LrView'
local LrApplication = import "LrApplication"
local logger = import 'LrLogger' ('ApplePhotosExportServiceProvider'):enable("logfile")

local bind = LrView.bind
local share = LrView.share

local MSG_SCANNING = "Retrieving folder structure from Apple Photos..."
local MSG_NOT_SELECTED = "You haven't specified a destination album"
local MSG_ROOT_EXPLANATION = "Don't put album inside any folder"
local MSG_FOLDER_EXPLANATION = "Place images in an album inside this folder"
local MSG_ALBUM_NAME_LENGTH = "Album name is too long"
local MSG_PUBLISH_ROOT_EXPLANATION = "Don't put published folders and albums in any folder (not recommended)"
local MSG_PUBLISH_FOLDER_EXPLANATION = "Create published folders and albums inside this folder"
local MAX_ALBUM_NAME_LEN_BYTES = 120


-- Lightroom doesn't differentiate between export and publish service providers, with
-- the SPI for one being a superset of the other. We call this an export service provider
-- but it's really both.
local exportServiceProvider = {}

exportServiceProvider.supportsIncrementalPublish = true

-- Export service properties
exportServiceProvider.hideSections = { 'exportLocation', 'video' }
exportServiceProvider.allowFileFormats = { 'JPEG' }
exportServiceProvider.allowColorSpaces = { 'sRGB' }
exportServiceProvider.hidePrintResolution = true
exportServiceProvider.canExportVideo = false

exportServiceProvider.exportPresetFields = {
    { key = 'selectedFolder',        default = nil },
    { key = 'selectedAlbum',         default = nil },
    { key = 'exportToExistingAlbum', default = false },
    { key = 'newAlbumName',          default = '' },
}

-- Publish service specific properties
exportServiceProvider.small_icon = 'resources/photos-small.png'
exportServiceProvider.titleForPublishedCollection = "Album"
exportServiceProvider.titleForPublishedCollectionSet = "Folder"
exportServiceProvider.titleForPublishedSmartCollection = "Smart Album"
exportServiceProvider.titleForGoToPublishedCollection = "disable" -- TODO: implement
exportServiceProvider.titleForGoToPublishedPhoto = "disable"      -- TODO: implement
exportServiceProvider.supportsCustomSortOrder = false

exportServiceProvider.disableRenamePublishedCollection = false
exportServiceProvider.disableRenamePublishedCollectionSet = false

function exportServiceProvider.metadataThatTriggersRepublish(publishSettings)
    return {
        default = false,
        title = true,
        caption = true,
        keywords = true,
        gps = true,
        dateCreated = true,
    }
end

-- Local helper functions

local function updateCantExportAndHelptext(propertyTable)
    logger:info("updateCantExportAndHelptext")

    -- if we're scanning flag that and stop
    if propertyTable.scanningFolders then
        propertyTable.LR_cantExportBecause = MSG_SCANNING
        propertyTable.helpText = MSG_SCANNING
        return
    end

    -- not scanning, folder dropdown must be populated with at least root, set helptext
    if propertyTable.selectedFolder == 'root' then
        if propertyTable.LR_isExportForPublish then
            propertyTable.helpText = MSG_PUBLISH_ROOT_EXPLANATION
        else
            propertyTable.helpText = MSG_ROOT_EXPLANATION
        end
    else
        if propertyTable.LR_isExportForPublish then
            propertyTable.helpText = MSG_PUBLISH_FOLDER_EXPLANATION
        else
            propertyTable.helpText = MSG_FOLDER_EXPLANATION
        end
    end

    if not propertyTable.LR_isExportForPublish then
        -- check album selection to decide whether export is allowed
        local validAlbumSpecified = (propertyTable.selectedAlbum ~= nil and
                propertyTable.exportToExistingAlbum) or
            (propertyTable.newAlbumName ~= nil and
                propertyTable.newAlbumName ~= "" and
                not propertyTable.exportToExistingAlbum)

        if not validAlbumSpecified then
            propertyTable.LR_cantExportBecause = MSG_NOT_SELECTED
            return
        end
    end

    propertyTable.LR_cantExportBecause = nil
end

-- Export/Publish service implementation

function exportServiceProvider.startDialog(propertyTable)
    logger:info("startDialog: " .. tostring(not not propertyTable.LR_isExportForPublish))

    if propertyTable.LR_isExportForPublish then
        propertyTable:addObserver('selectedFolder', function() updateCantExportAndHelptext(propertyTable) end)
    else
        propertyTable:addObserver('selectedAlbum', function() updateCantExportAndHelptext(propertyTable) end)
        propertyTable:addObserver('exportToExistingAlbum', function() updateCantExportAndHelptext(propertyTable) end)
        propertyTable:addObserver('newAlbumName', function() updateCantExportAndHelptext(propertyTable) end)
    end
    propertyTable:addObserver('scanningFolders', function() updateCantExportAndHelptext(propertyTable) end)
    updateCantExportAndHelptext(propertyTable)

    propertyTable.folderList = {}
    propertyTable.albumMap = {}
    propertyTable.exportToExistingAlbum = true
    propertyTable.scanningFolders = false

    ApplePhotosAPI.queryFolderStructure(propertyTable)
end

function exportServiceProvider.sectionsForTopOfDialog(f, propertyTable)
    logger:info("sectionsForTopOfDialog")

    if propertyTable.LR_isExportForPublish then
        return {
            {
                title = "Destination Folder",
                synopsis = function(props)
                    local selectedFolder = props.selectedFolder
                    local folderName = nil
                    for _, value in ipairs(props.folderList) do
                        if value.value == selectedFolder then
                            folderName = value.title
                            break
                        end
                    end
                    return folderName
                end,
                f:column {
                    spacing = f:control_spacing(),

                    f:row {
                        spacing = f:label_spacing(),
                        f:static_text {
                            title = "Folder:",
                            alignment = "right",
                            width = share 'destinationLeftTitle',
                            enabled = LrBinding.negativeOfKey 'scanningFolders',
                        },
                        f:popup_menu {
                            value = bind 'selectedFolder',
                            items = bind 'folderList',
                            enabled = LrBinding.negativeOfKey 'scanningFolders'
                        },
                        f:static_text {
                            title = bind 'helpText',
                            alignment = "left",
                            width_in_chars = 60
                        }
                    },
                },
            }
        }
    else
        return {
            {
                title = "Destination Album",
                synopsis = function(props)
                    if props.exportToExistingAlbum then
                        local existingAlbums = props.albumMap[props.selectedFolder]
                        local existingAlbumID = props.selectedAlbum
                        local existingAlbumName = nil
                        for _, value in ipairs(existingAlbums) do
                            if value.value == existingAlbumID then
                                existingAlbumName = value.title
                                break
                            end
                        end
                        return existingAlbumName
                    else
                        return props.newAlbumName
                    end
                end,
                f:column {
                    spacing = f:control_spacing(),

                    f:row {
                        spacing = f:label_spacing(),
                        f:static_text {
                            title = "Folder:",
                            alignment = "right",
                            width = share 'destinationLeftTitle',
                            enabled = LrBinding.negativeOfKey 'scanningFolders',
                        },
                        f:popup_menu {
                            value = bind 'selectedFolder',
                            items = bind 'folderList',
                            enabled = LrBinding.negativeOfKey 'scanningFolders'
                        },
                        f:static_text {
                            title = bind 'helpText',
                            alignment = "left",
                            width_in_chars = 60
                        }
                    },
                    f:row {
                        spacing = f:label_spacing(),
                        f:static_text {
                            title = "Album:",
                            alignment = "right",
                            width = share 'destinationLeftTitle',
                            enabled = LrBinding.negativeOfKey 'scanningFolders'
                        },
                        f:popup_menu {
                            value = bind 'selectedAlbum',
                            items = LrView.bind {
                                keys = { "albumMap", "selectedFolder" },
                                operation = function(binder, values, fromTable)
                                    local albumMap = values.albumMap
                                    local selectedFolder = values.selectedFolder
                                    local albumList = albumMap[selectedFolder]
                                    if albumList == nil then
                                        albumList = {}
                                        propertyTable.selectedAlbum = nil
                                        propertyTable.exportToExistingAlbum = false
                                    else
                                        propertyTable.exportToExistingAlbum = true
                                        -- try to find the previously set element in the new list (this is mainly for preset loading)
                                        for _, value in pairs(albumList) do
                                            if value.value == propertyTable.selectedAlbum then
                                                return albumList
                                            end
                                        end
                                        -- didn't find a match so reset to first value
                                        propertyTable.selectedAlbum = albumList[1].value
                                    end
                                    return albumList
                                end,
                            },
                            enabled = bind 'exportToExistingAlbum'
                        },
                        f:spacer {
                            width = 20
                        },
                        f:checkbox {
                            title = "Create New Album:",
                            value = LrBinding.negativeOfKey 'exportToExistingAlbum',
                            enabled = LrBinding.negativeOfKey 'scanningFolders'

                        },
                        f:edit_field {
                            value = bind 'newAlbumName',
                            immediate = true,
                            width_in_chars = 30,
                            enabled = LrBinding.negativeOfKey 'exportToExistingAlbum',
                            validate = function(view, value)
                                local message = nil
                                local result = true

                                if #value > MAX_ALBUM_NAME_LEN_BYTES then
                                    message = MSG_ALBUM_NAME_LENGTH
                                    result = false
                                end

                                return result, value, message
                            end
                        },
                    }
                },
            }
        }
    end
end

function exportServiceProvider.processRenderedPhotos(functionContext, exportContext)
    logger:info("Starting export")
    local exportSession = exportContext.exportSession
    local exportSettings = assert(exportContext.propertyTable)
    local publishService = exportContext.publishService
    local nPhotos = exportSession:countRenditions()
    local processedCount = 0

    -- Set progress title.
    local progressScope = exportContext:configureProgress {
        title = nPhotos > 1
            -- note, this text is ignored when publishing
            and LOC("$$$/ApplePhotos/Progress=Exporting ^1 photos to Apple Photos", nPhotos)
            or LOC "$$$/ApplePhotos/Progress/One=Exporting one photo to Apple Photos",
    }

    local targetAlbumID = nil
    progressScope:setCaption("Setting up target album")

    if publishService then
        -- we're in a publish flow
        logger:info("Setting up album for Publish")
        local publishedCollectionInfo = exportContext.publishedCollectionInfo
        local remoteAlbumID = publishedCollectionInfo.remoteId
        if remoteAlbumID then
            logger:info("Checking existing target album :" .. remoteAlbumID)
            local foundName = ApplePhotosAPI.checkAlbumExists(remoteAlbumID)
            if foundName then
                logger:info("Found existing target album, will reuse")
                targetAlbumID = remoteAlbumID
            else
                logger:info("Target album is missing, will recreate")
            end
        end
        if not targetAlbumID then
            logger:info("Creating target album")

            local lastParentID = "root"
            local lastParent = publishedCollectionInfo.parents[#publishedCollectionInfo.parents]
            if lastParent then
                assert(lastParent.remoteCollectionId, "parent collection set has no remote ID")
                lastParentID = lastParent.remoteCollectionId
            end
            ---@diagnostic disable-next-line: cast-local-type
            targetAlbumID = ApplePhotosAPI.createAlbum(publishedCollectionInfo.name, lastParentID)
            assert(targetAlbumID, "Unable to create target album")

            exportSession:recordRemoteCollectionId(targetAlbumID)
        end
    else
        -- we're in an export flow
        logger:info("Setting up album for Export")
        if not exportSettings.exportToExistingAlbum then
            ---@diagnostic disable-next-line: cast-local-type
            targetAlbumID = ApplePhotosAPI.createAlbum(exportSettings.newAlbumName, exportSettings.selectedFolder)
            assert(targetAlbumID, "Unable to create target album")
        else
            logger:info("Using existing target album :" .. exportSettings.selectedAlbum)
            targetAlbumID = exportSettings.selectedAlbum
        end
    end

    assert(targetAlbumID, "Target album does not exist/cannot be created")

    logger:info("Ready to export to: " .. targetAlbumID)

    local renditionsToUpdate = {}
    local newRenditions = {}

    for _, rendition in exportSession:renditions() do
        logger:info("Analyzing image: " .. rendition.photo.localIdentifier)
        if publishService then
            local existingImageID = rendition.publishedPhotoId
            if existingImageID then
                -- replace
                logger:info("Rendition has remote image ID: " .. existingImageID .. " - marking to update")
                table.insert(renditionsToUpdate, rendition)
            else
                -- new publish
                logger:info("Rendition is new published image")
                table.insert(newRenditions, rendition)
            end
        else
            -- all exports
            logger:info("Rendition is new exported image")
            table.insert(newRenditions, rendition)
        end
    end

    progressScope:setCaption("Adding new images")
    logger:info("Starting new image additions")
    for _, rendition in ipairs(newRenditions) do
        if progressScope:isCanceled() then break end

        local success, pathOrMessage = rendition:waitForRender()
        if success then
            local imageID = ApplePhotosAPI.importPhoto(targetAlbumID, pathOrMessage)
            logger:info("Import OK: " .. imageID)

            if publishService then
                logger:info("Setting remote photo ID: " .. imageID)
                rendition:recordPublishedPhotoId(imageID)
            end
        else
            rendition:uploadFailed(pathOrMessage)
        end

        -- Manually advance the progress bar
        processedCount = processedCount + 1
        progressScope:setPortionComplete(processedCount, nPhotos)
    end


    if publishService then
        progressScope:setCaption("Updating modified images")
        logger:info("Starting modified image updates")
        local replacementRecords = {}
        for _, rendition in ipairs(renditionsToUpdate) do
            if progressScope:isCanceled() then break end

            local success, pathOrMessage = rendition:waitForRender()
            if success then
                replacementRecords[rendition.publishedPhotoId] = pathOrMessage
            else
                rendition:uploadFailed(pathOrMessage)
            end

            -- Manually advance the progress bar
            processedCount = processedCount + 1
            progressScope:setPortionComplete(processedCount, nPhotos)
        end

        ApplePhotosAPI.replacePhotos(replacementRecords)
    end

    progressScope:done()

    -- for _, rendition in exportContext:renditions { stopIfCanceled = true } do
    --     logger:info("Processing image: " .. rendition.photo.localIdentifier)
    --     if not rendition.wasSkipped then
    --         local success, pathOrMessage = rendition:waitForRender()
    --         if progressScope:isCanceled() then break end
    --         if success then
    --             local shouldImport = true
    --             if publishService then
    --                 local existingImageID = rendition.publishedPhotoId
    --                 if existingImageID then
    --                     -- replace
    --                     logger:info("Rendition has remote image ID: " .. existingImageID .. " marking to update")
    --                     table.insert(renditionsToUpdate, rendition)
    --                     shouldImport = false
    --                 end
    --             end

    --             if shouldImport then
    --                 local imageID = ApplePhotosAPI.importPhoto(targetAlbumID, pathOrMessage)
    --                 logger:info("Import OK: " .. imageID)

    --                 if publishService then
    --                     logger:info("Setting remote photo ID: " .. imageID)
    --                     rendition:recordPublishedPhotoId(imageID)
    --                 end
    --             end
    --         end
    --     end
    -- end
end

-- Publish service implementation

function exportServiceProvider.deletePhotosFromPublishedCollection(publishSettings, arrayOfPhotoIds, deletedCallback)
    logger:info("deletePhotosFromPublishedCollection")

    local deletedIDs = ApplePhotosAPI.deleteImages(arrayOfPhotoIds)
    for _, photoId in ipairs(deletedIDs) do
        deletedCallback(photoId)
    end
end

function exportServiceProvider.renamePublishedCollection(publishSettings, info)
    logger:info("renamePublishedCollection")

    local pc = info.publishedCollection

    if info.remoteId then
        if pc:type() == "LrPublishedCollection" then
            -- album/collection
            local success = ApplePhotosAPI.renameAlbum(info.remoteId, info.name)
            if not success then
                error("Unable to rename album: " .. info.remoteId)
            end
        else
            -- folder/collectionset
            local success = ApplePhotosAPI.renameFolder(info.remoteId, info.name)
            if not success then
                error("Unable to rename folder: " .. info.remoteId)
            end
        end
    end
end

-- This is invoked on creation or rename of a published collection set.
-- Rename also invokes renamePublishedCollection, so we only handle creation here.
function exportServiceProvider.updateCollectionSetSettings(publishSettings, info)
    local pc = info.publishedCollection
    local folderName = info.name
    local baseFolderID = "root"

    -- if there's no remote ID set, this is a collection set we don't know about, so create it
    if not pc:getRemoteId() then
        local directAncestor = info.parents and info.parents[#info.parents] or nil
        if directAncestor and directAncestor.remoteCollectionId then
            baseFolderID = directAncestor.remoteCollectionId
        end

        logger:info("baseFolderID: " .. baseFolderID)

        local newFolderID = ApplePhotosAPI.createFolder(folderName, baseFolderID)

        LrApplication.activeCatalog():withWriteAccessDo("RecordCollectionSetID", function(context)
            pc:setRemoteId(newFolderID)
            logger:info("newFolderID: " .. newFolderID)
        end)
    end

    logger:info("done")
end

function exportServiceProvider.reparentPublishedCollection(publishSettings, info)
    logger:info("reparentPublishedCollection")
end

function exportServiceProvider.deletePublishedCollection(publishSettings, info)
    logger:info("deletePublishedCollection")

    local pc = info.publishedCollection

    -- for key, _ in pairs(info) do
    --     logger:info(key)
    -- end

    -- local photos = info.photoIds
    -- logger:info("photoids: " .. photos and #photos or "nil")

    if info.remoteId then
        if pc:type() == "LrPublishedCollection" then
            logger:info("type is collection")
            -- album/collection
            -- local success = ApplePhotosAPI.deleteAlbum(info.remoteId)
            -- if not success then
            --     error("Unable to delete album: " .. info.remoteId)
            -- end
            error("foo")
        else
            logger:info("type is collectionset")
            -- folder/collectionset
            local success = ApplePhotosAPI.deleteFolder(info.remoteId)
            if not success then
                error("Unable to delete folder: " .. info.remoteId)
            end
        end
    end
end

---------------
return exportServiceProvider
