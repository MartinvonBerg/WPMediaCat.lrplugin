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

local p2 = LrPathUtils.getStandardFilePath( 'documents' ) -- MAC also

if WIN_ENV then
    Log('Running on Windows')
    DIRSEP = '\\'
else
    Log('Running on macOS')
    DIRSEP = '/'
end

-- check availability of ImageMagick on start-up 
local filepath = p2 .. DIRSEP .. 'LRTestImagick.txt'

-- delete-file First
if LrFileUtils.exists( filepath ) then
    LrFileUtils.delete( filepath )
end

LrTasks.startAsyncTask( function(  )
        local p2 = LrPathUtils.getStandardFilePath( 'documents' )
        
        -- do test for availability Imagemagick 
        local cmd = 'magick -version > "' .. p2 .. DIRSEP ..'LRTestImagick.txt"' 
        
        Log ('Checking ImageMagick: ', cmd)
        LrTasks.execute( cmd ) 
    end 
)
