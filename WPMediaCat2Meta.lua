--Definitions of the MetaData for the Plug-in. 
-- ATTENTION: Bei Änderungen muss die schemaversion hochgezählt werden!

return {
    schemaVersion = 9, -- increment this value any time you make a change to the field definitions below
   
    metadataFieldsForPhotos = {
        { version = 9, dataType="string", searchable=true, browsable=true, readOnly=true, id="wpid", title="WordPress-Id" },
        { version = 9, dataType="string", searchable=true, browsable=true, readOnly=true, id="upldate", title=LOC "$$$/WP_MediaCat2/Meta/UploadDate=Upload Date" },
        { version = 9, dataType="string", searchable=true, browsable=true, readOnly=true, id="wpwidth", title=LOC "$$$/WP_MediaCat2/Meta/width=Width (full)"  },
        { version = 9,  dataType="string", searchable=true, browsable=true, readOnly=true, id="wpheight", title=LOC "$$$/WP_MediaCat2/Meta/height=Height (full)"  },
        { version = 9, dataType="url", searchable=true, browsable=true, readOnly=true, id="wpimgurl", title=LOC "$$$/WP_MediaCat2/Meta/wpurl=WP Image url"  },
        { version = 9, dataType="string", searchable=true, browsable=true, readOnly=true, id="slug", title="Slug"  },
        { version = 9, dataType="url", searchable=true, browsable=true, readOnly=true, id="post", title="Post"  },
        { version = 9, dataType="string", searchable=true, browsable=true, readOnly=true, id="gallery", title=LOC "$$$/WP_MediaCat2/Meta/gallery=Gallery"  },
    }
}