-- Initialization Routine running at plugin loading
-- Define globals: load the file with globals 
require('PluginGlobals')
JSON=require 'JSON'

----- Debug -----------
--logDebug = true
--require 'strict'
require 'Logger'
InitLogger( false ) -- true for logging.
DebugSync = false
inspect = require 'inspect'
----- Debug ------------

local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

-- os dependent settings as globals
if WIN_ENV then
    Log('Running on Windows')
    DIRSEP = '\\'
    os = 'WIN'
else
    Log('Running on macOS')
    DIRSEP = '/'
    os = 'macOS'
end

-- check availability of ImageMagick on start-up 
local p2 = LrPathUtils.getStandardFilePath( 'documents' ) 
local filepath = p2 .. DIRSEP .. 'LRTestImagick.txt'
local filepath2 = p2 .. DIRSEP .. 'LRTestVips.txt'
pipath = _PLUGIN.path

-- delete-file First
if LrFileUtils.exists( filepath ) then
    LrFileUtils.delete( filepath )
end

if LrFileUtils.exists( filepath2 ) then
    LrFileUtils.delete( filepath2 )
end

LrTasks.startAsyncTask( function(  )
        local p2 = LrPathUtils.getStandardFilePath( 'documents' )
        local cmd = ''
        local cmd2 = ''
        
        -- do test for availability Imagemagick 
        if WIN_ENV then
            cmd = 'magick -version > "' .. filepath .. '"' 
            -- add a test for vips
            cmd2 = 'vips --vips-config > "' .. filepath2 .. '"'
        else
            cmd  = pipath .. '/magick -version > ' .. filepath
            cmd2 = pipath .. '/vips --vips-config > ' .. filepath2
        end
        
        Log ('Checking ImageMagick: ', cmd)
        LrTasks.execute( cmd ) 
        Log ('Checking libvips: ', cmd2)
        LrTasks.execute( cmd2 )
    end 
)
