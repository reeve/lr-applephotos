return {

    LrSdkVersion = 3.0,
    LrSdkMinimumVersion = 1.3, -- minimum SDK version required by this plug-in

    LrToolkitIdentifier = 'com.adamreeve.lightroom.lr-applephotos',

    LrPluginName = "Export and Publish to Apple Photos",

    LrExportServiceProvider = {
        title = "Apple Photos",
        file = 'ApplePhotosExportServiceProvider.lua',
    },

    VERSION = { major = 1, minor = 0, revision = 0, build = 0, },

}
