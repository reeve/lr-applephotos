require 'ApplePhotosAPI'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'
local logger = import 'LrLogger' ('ApplePhotosExportServiceProvider'):enable("logfile")

local bind = LrView.bind
local share = LrView.share

local MSG_SCANNING = "Retrieving folder structure from Apple Photos..."
local MSG_NOT_SELECTED = "You haven't specified a destination album"
local MSG_ROOT_EXPLANATION = "Place images in an album which is not inside any folder"
local MSG_FOLDER_EXPLANATION = "Place images in an album inside this folder"
local MSG_ALBUM_NAME_LENGTH = "Album name limited to 100 characters"
local MAX_ALBUM_NAME_LEN_BYTES = 120

local exportServiceProvider = {}

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

local function updateCantExportAndHelptext(propertyTable)
    -- if we're scanning flag that and stop
    if propertyTable.scanningFolders then
        propertyTable.LR_cantExportBecause = MSG_SCANNING
        propertyTable.helpText = MSG_SCANNING
        return
    end

    -- not scanning, folder dropdown must be populated with at least root, set helptext
    if propertyTable.selectedFolder == 'root' then
        propertyTable.helpText = MSG_ROOT_EXPLANATION
    else
        propertyTable.helpText = MSG_FOLDER_EXPLANATION
    end

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

    propertyTable.LR_cantExportBecause = nil
end

function exportServiceProvider.startDialog(propertyTable)
    logger:info("startDialog")

    propertyTable:addObserver('selectedAlbum', function() updateCantExportAndHelptext(propertyTable) end)
    propertyTable:addObserver('exportToExistingAlbum', function() updateCantExportAndHelptext(propertyTable) end)
    propertyTable:addObserver('newAlbumName', function() updateCantExportAndHelptext(propertyTable) end)
    propertyTable:addObserver('scanningFolders', function() updateCantExportAndHelptext(propertyTable) end)
    updateCantExportAndHelptext(propertyTable)

    propertyTable.folderList = {}
    propertyTable.albumMap = {}
    propertyTable.exportToExistingAlbum = true
    propertyTable.scanningFolders = false

    ApplePhotosAPI.updateFolderStructure(propertyTable)
end

function exportServiceProvider.sectionsForTopOfDialog(f, propertyTable)
    logger:info("sectionsForTopOfDialog")

    -- if propertyTable.LR_isExportForPublish then
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
                                logger:info("album popup values refresh")
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
    -- else
    --     return {}
    -- end
end

function exportServiceProvider.processRenderedPhotos(functionContext, exportContext)
    local exportSession = exportContext.exportSession
    local exportSettings = assert(exportContext.propertyTable)

    local nPhotos = exportSession:countRenditions()

    -- Set progress title.

    local progressScope = exportContext:configureProgress {
        title = nPhotos > 1
            and LOC("$$$/ApplePhotos/Progress=Exporting ^1 photos to Apple Photos", nPhotos)
            or LOC "$$$/ApplePhotos/Progress/One=Exporting one photo to Apple Photos",
    }

    local exportAlbumID = "root"

    if not exportSettings.exportToExistingAlbum then
        exportAlbumID = ApplePhotosAPI.createFolder(exportSettings.newAlbumName, exportSettings.selectedFolder)
    else
        exportAlbumID = exportSettings.selectedAlbum
    end

    local exportedPhotoIds = {}

    for i, rendition in exportContext:renditions { stopIfCanceled = true } do
        -- progressScope:setPortionComplete((i - 1) / nPhotos)
        if not rendition.wasSkipped then
            local success, pathOrMessage = rendition:waitForRender()
            -- progressScope:setPortionComplete((i - 0.5) / nPhotos)
            if progressScope:isCanceled() then break end
            if success then
                ApplePhotosAPI.importPhoto(exportAlbumID, pathOrMessage, exportSettings)
            end
        end
    end
    -- progressScope:done()
end

---------------

return exportServiceProvider
