local LrLogger = import 'LrLogger'
require 'ApplePhotosAPI'

-- Create the logger and enable the print function.
local myLogger = LrLogger('evalEntrypoint')
myLogger:enable("logfile") -- Pass either a string or a table of actions.

--------------------------------------------------------------------------------
-- Write trace information to the logger.

local function outputToLog(message)
    myLogger:warn(message)
end

--------------------------------------------------------------------------------

myLogger:warn(ApplePhotosAPI.getFolderStructure())
