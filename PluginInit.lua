-- Initialization Routine running at plugin loading
-- Define globals: load the file with globals 
require('PluginGlobals')

----- Debug -----------
logDebug = true
--require 'strict'
require 'Logger'
DebugSync = false
inspect = require 'inspect'
----- Debug ------------

local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

-- checking whether ImageMagick command magick is available
if WIN_ENV then
    Log('Running on Windows')

    -- check availability of ImageMagick on start-up 
    local p2 = LrPathUtils.getStandardFilePath( 'documents' ) -- MAC also
    local filepath = p2 .. '\\LRTestImagick.txt' -- WIN only

    -- delete-file First
    if LrFileUtils.exists( filepath ) then
        LrFileUtils.delete( filepath )
    end

    LrTasks.startAsyncTask( function(  )
            local p2 = LrPathUtils.getStandardFilePath( 'documents' )
            
            -- do test for availability Imagemagick 
            local cmd = 'magick -version > "' .. p2 .. '\\LRTestImagick.txt"' 
            
            Log ('Checking ImageMagick: ', cmd)
            LrTasks.execute( cmd ) 
        end 
    )
else
    Log('Running on macOS')
    -- Currently is no conversion from jpg to webp available
    -- Ore more detailed: The installation of ImageMagick is quite complicated and only for developpers.
    -- So we skip this for macOS. 
end