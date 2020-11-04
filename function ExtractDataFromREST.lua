function ExtractDataFromREST( restdata )
    -- aus einer REST-Antwort zu einer Datei die Daten für customMetadata extrahieren
    -- Parameter restdata: JSON-Format der REST-Antwort
    local i = 1
    local result = {} 
    result[i] = restdata
    local row = {}
    local keyfound = false
    local lrid
    local w1, w2
  
    local str = inspect(result[i]) -- JSON-Rückgabe für ein Image in str umwandeln
    local ii,j = string.find(str,'full') -- den vollen Filename suchen
    if ii ~= nil then
      keyfound = true  -- Der filename ist in der Rest-Antwort enthalten
    end
    
    local function findTextinHTML( html )
      -- find text in HTML-Tag from REST-Api-Data
      -- Parameter: html : string
      local w1, w2, text
      w1, w2 = string.find(html, '<p>.*</p>')
      if w1 ~=nil and w2 ~= nil then
        text = string.sub(html,w1+3,w2-4)
      else
        text = ''
      end
      return text
    end
  
    local _descr = result[i].description.rendered or ''  
    _descr = findTextinHTML(_descr)
   
    local _caption = result[i].caption.rendered or ''
    _caption = findTextinHTML(_caption)
   
    row = {lrid = {}, id = result[i].id, 
                        upldate = result[i].date, 
                        width = result[i].media_details.width, 
                        height = result[i].media_details.height, 
                        slug = result[i].slug, 
                        post = result[i].post, 
                        gallery = result[i].gallery, 
                        phurl = result[i].source_url, 
                        datemod = result[i].modified, 
                        title = result[i].title.rendered,
                        descr = _descr,  
                        caption = _caption,
                        alt  = result[i].alt_text, 
                        origfile = result[i].media_details.original_image,  -- Fehler, wenn nicht vorhanden?
            } 
  
    if keyfound then
      row = {filen = result[i].media_details.sizes.full.file,}
    else
      local fname = result[i].media_details.file
      fname = getfile(fname)
      row = {filen = fname,} 
    end
  
    return row
  end