require 'ApplePhotosAPI'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'
local logger = import 'LrLogger' ('ApplePhotosExportServiceProvider'):enable("logfile")

local bind = LrView.bind
local share = LrView.share

local exportServiceProvider = {}

exportServiceProvider.hideSections = { 'exportLocation', 'video' }
exportServiceProvider.allowFileFormats = { 'JPEG' }
exportServiceProvider.allowColorSpaces = { 'sRGB' }
exportServiceProvider.hidePrintResolution = true
exportServiceProvider.canExportVideo = false


local function updateCantExportBecause(propertyTable)
    local validAlbumSpecified = (propertyTable.selectedAlbum ~= nil and
            propertyTable.exportToExistingAlbum) or
        (propertyTable.newAlbumName ~= nil and
            propertyTable.newAlbumName ~= "" and
            not propertyTable.exportToExistingAlbum)


    if not validAlbumSpecified then
        propertyTable.LR_cantExportBecause = "You haven't specified a destination album."
        return
    end

    propertyTable.LR_cantExportBecause = nil
end

function exportServiceProvider.startDialog(propertyTable)
    logger:info("startDialog")

    propertyTable:addObserver('selectedAlbum', function() updateCantExportBecause(propertyTable) end)
    propertyTable:addObserver('exportToExistingAlbum', function() updateCantExportBecause(propertyTable) end)
    propertyTable:addObserver('newAlbumName', function() updateCantExportBecause(propertyTable) end)
    updateCantExportBecause(propertyTable)

    propertyTable.folderList = {}
    propertyTable.albumMap = {}
    propertyTable.exportToExistingAlbum = true

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
                    },
                    f:popup_menu {
                        value = bind 'selectedFolder',
                        items = bind 'folderList'
                    },
                    f:static_text {
                        title = "Albums not inside any folder",
                        alignment = "left",
                        visible = LrBinding.keyEquals('selectedFolder', 'root'),
                    }
                },
                f:row {
                    spacing = f:label_spacing(),
                    f:static_text {
                        title = "Album:",
                        alignment = "right",
                        width = share 'destinationLeftTitle',
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
                                    propertyTable.exportToExistingAlbum = false
                                else
                                    propertyTable.selectedAlbum = albumList[1].value
                                    propertyTable.exportToExistingAlbum = true
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
                    },
                    f:edit_field {
                        value = bind 'newAlbumName',
                        immediate = true,
                        width_in_chars = 30,
                        enabled = LrBinding.negativeOfKey 'exportToExistingAlbum'
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
