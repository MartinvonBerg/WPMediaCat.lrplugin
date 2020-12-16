JSON=require 'JSON'
require 'strict'
local inspect = require 'inspect'

-- array ist einfache Tabelle als liste mit Stringwerten, wie von strsplit gelifert
  -- Annahme, dass der Wert nur einmal vorhanden ist
  function findValueInArray (array, key, depth, parent)
    local result = 0
    parent = parent or 0
    
    if depth == '' or depth == nil then
        for i=1, #array do
            if array[i] == key then
                result = i
                break
            end
        end
    end

    if depth ==1 then
        for i=1, #array do
            if array[i][depth][1] == key then
                result = i
                break
            end
        end
    end
    -----------------------------
    if depth ==2 and array[parent][depth] ~= nil then
        for i=1, #array[parent][depth] do
            if array[parent][depth][i][1] == key then
                result = i
                break
            end
        end
    end
  -------------------------------
    if depth ==3 and array[parent][depth] ~= nil then
      for i=1, #array[parent][depth] do
          if array[parent][depth][i][1] == key then
              result = i
              break
          end
      end
    end

    return result
  end
  
  function strsplit(string, sSeparator, nMax, bRegexp)
	-- split string by given seperator
    if sSeparator == '' then
        sSeparator = ','
    end

    if nMax and nMax < 1 then
        nMax = nil
    end

    local aRecord = {}

    if string:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1

        local nField, nStart = 1, 1
        local nFirst,nLast = string:find(sSeparator, nStart, bPlain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = string:sub(nStart, nFirst-1)
            nField = nField+1
            nStart = nLast+1
            nFirst,nLast = string:find(sSeparator, nStart, bPlain)
            nMax = nMax-1
        end
        aRecord[nField] = string:sub(nStart)
    end

    return aRecord
end


local filearray = { 'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Franken-Dennenlohe/Bike-Hike-Col-de-Peas-601.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums1/Franken-1/Franken-2020-05-184_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums1/Franken-2/Franken-2020-05-166_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums1/Franken-2/Franken-2020-05-160_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums2/Franken-3/Franken-2020-05-156_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums2/Franken-3/Franken-2020-05-150_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums3/Franken-4/Franken-2020-05-142_DxO_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums3/Franken-5/Franken-2020-05-136_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums3/Franken-5/Franken-2020-05-115_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums3/Franken-6/Franken-2020-05-97_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Franken-Dennenlohe/Franken-2020-05-85_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Franken-Dennenlohe/Franken-2020-05-77_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Franken-Dennenlohe/Franken-2020-05-72_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Franken-Dennenlohe/Franken-2020-05-65_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Franken-Dennenlohe/Franken-2020-05-43_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Franken-Dennenlohe/Franken-2020-05-27_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Franken-Dennenlohe/Franken-2020-05-23_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Franken-Dennenlohe/Franken-2020-05-17_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Franken-Dennenlohe/Franken-2020-05-11_DxO.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Uebersee_2017_01_50-55-Bearbeitet.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Spanien_2016_06-67.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Schottland_2018-05-364.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Santorin90_084.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/NZ_Ausw_1L_114.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Norge_2017_08-1001.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Madeira_2019_04-261.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Italien_2018_12-357.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Haus_2013_298.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Gardasee_10_10_058.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Chile97_Ausw_055.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Chiemgau_2017_10_-105.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/BrgT2000_017.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Bretagne_10_08_144.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Albums/Bratisl_2018_02_078-Bearbeitet.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Bike-Hike-Col-de-Peas/Bike-Hike-Col-de-Peas-700.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/2020/11/Spanien_2016_06-981.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/2020/11/Spanien_2016_06-976.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/2020/11/Spanien_2016_06-963.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/2020/11/Spanien_2016_06-954.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/2020/11/Spanien_2016_06-943.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/2020/11/Bretagne_10_08_346.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Bike-Hike-Col-de-Peas/Bike-Hike-Col-de-Peas-695.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Bike-Hike-Col-de-Peas/Bike-Hike-Col-de-Peas-682.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Bike-Hike-Col-de-Peas/Bike-Hike-Col-de-Peas-675.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Bike-Hike-Col-de-Peas/Bike-Hike-Col-de-Peas-658.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Bike-Hike-Col-de-Peas/Bike-Hike-Col-de-Peas-651.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Bike-Hike-Col-de-Peas/Bike-Hike-Col-de-Peas-646.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Bike-Hike-Col-de-Peas/Bike-Hike-Col-de-Peas-642-2-2-2.jpg',
'http://127.0.0.1/wordpress/wp-content/uploads/Foto_Albums/Bike-Hike-Col-de-Peas/Bike-Hike-Col-de-Peas-622.jpg',
'/uploads/Foto_Albums3/Bike-Hike/test.jpg',
'/uploads/Foto_Albums3/Wanderung-Hike/test.jpg',
'/uploads/Foto_Albums3/Camping-Hike/test.jpg',
'/uploads/Foto_Albums3/Meer/test.jpg',
'/uploads/Foto_Albums4/Bike-Hike/test.jpg',
'/uploads/Foto_Albums5/Bike-Hike/test.jpg',
 }


-- Collection und CollectionSet bestimmen
local collections = {}
local level1 = 1
local level2 = 1
local paths = {}
local npaths = 1
  
for i=1, #filearray do
  local path = filearray[i]
  local pathlist = strsplit(path, '/' )
  local str = inspect(pathlist)
  local uploadindex = findValueInArray (pathlist, 'uploads')
  local depth = 1
  local sub =''
 
  for c=uploadindex+1, #pathlist-1 do -- hier wird immer nur ein pfad durchsucht
    sub = sub .. pathlist[c] .. '/'
    
    
    
    local ctype = 'CollSet'
    if c == #pathlist-1 then
      ctype = 'Coll'
    end
    ---------------------
    if depth == 1 then
      if findValueInArray(collections, pathlist[c], depth) == 0 then
        collections[level1] = {}
        collections[level1][depth] = { pathlist[c], ctype, 'object'}
        level1 = level1 +1
      end
      
    end
    ----------------------------
    if depth == 2 then
      local parent = findValueInArray(collections, pathlist[c-1], depth-1)
      --print(parent)
      
      if findValueInArray(collections, pathlist[c], depth, parent) == 0 then
        local bereitsvorhanden = 0
        if collections[parent][depth] ~= nil then
          bereitsvorhanden = #collections[parent][depth] 
        else
          collections[parent][depth] = {}
        end
                
        collections[parent][depth][bereitsvorhanden+1] = {}
        collections[parent][depth][bereitsvorhanden+1] = { pathlist[c], ctype, 'object'}
       
      end
      
    end
    -----------------------------
    if depth == 3 then
      local parent2 = findValueInArray(collections, pathlist[c-1], depth-1)

      -- Suche parent zu parent2
      local parent = findValueInArray(collections, pathlist[c-2], depth-2)
    
      
      if findValueInArray(collections, pathlist[c], depth, parent) == 0 then
        local bereitsvorhanden = 0
        if collections[parent][parent2][depth] ~= nil then
          bereitsvorhanden = #collections[parent][parent2][depth] 
        else
          collections[parent][parent2][depth] = {}
        end
                
        collections[parent][parent2][depth][bereitsvorhanden+1] = {}
        collections[parent][parent2][depth][bereitsvorhanden+1] = { pathlist[c], ctype, 'object'}
       
      end
      
    end
    -----------------------------

    depth = depth + 1
  end
  if findValueInArray(paths, sub) == 0 then
    local wpcatsub = string.match(sub, '%d%d%d%d/%d%d')
    if wpcatsub == nil then
      paths[npaths] = sub
      npaths = npaths +1
    end
  end
  --print (paths[i])
end

local pcoll = JSON:encode(paths) -- formatieren mit https://jsonformatter.org/json-pretty-print

print( pcoll )
