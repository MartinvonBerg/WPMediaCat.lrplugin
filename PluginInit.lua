-- init-datai

----- Debug -----------
--logDebug = false
require 'Logger'

if WIN_ENV then
    Log('Running on Windows')
else
    Log('Running on MAC')
end