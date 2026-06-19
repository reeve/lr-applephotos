return {

    LrSdkVersion = 3.0,
    LrSdkMinimumVersion = 1.3, -- minimum SDK version required by this plug-in

    LrToolkitIdentifier = 'com.adamreeve.lightroom.lr-applephotos',

    LrPluginName = "Apple Photos",

    LrExportMenuItems = {
        title = "Get Folders",
        file = "EvalEntrypoint.lua",
    },

    LrExportServiceProvider = {
        title = "Apple Photos",
        file = 'ApplePhotosExportServiceProvider.lua',
    },

    VERSION = { major = 0, minor = 1, revision = 0, build = 0, },

}
