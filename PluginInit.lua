-- Initialization Routine running at plugin loading

----- Debug -----------
--logDebug = false
require 'Logger'
----- Debug -----------

local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

-- check availability of ImageMagick on start-up 
local p2 = LrPathUtils.getStandardFilePath( 'documents' )
local filepath = p2 .. '\\LRTestImagick.txt'

-- delete-file First
if LrFileUtils.exists( filepath ) then
    LrFileUtils.delete( filepath )
end

-- checking whether ImageMagick command magick is available
if WIN_ENV then
    Log('Running on Windows')
    LrTasks.startAsyncTask( function(  )
            local p2 = LrPathUtils.getStandardFilePath( 'documents' )
            
            -- do test for Imagemagick  -- TODO: Include cmd for MAC also!
            local cmd = 'magick -version > "' .. p2 .. '\\LRTestImagick.txt"' 
            
            Log ('Checking ImageMagick: ', cmd)
            LrTasks.execute( cmd ) 
        end 
    )
else
    Log('Running on macOS')
end