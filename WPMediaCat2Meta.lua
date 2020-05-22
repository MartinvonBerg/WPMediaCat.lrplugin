--PMediaCat2Meta
return {
    schemaVersion = 4, -- increment this value any time you make a change to the field definitions below
   
    metadataFieldsForPhotos = {
     -- You can have as many fields as you like (the example below shows three)... just make sure each 'id' and 'title' are unique.
     -- Set "searchable" to true to allow as a search criteria in smart collections.
     -- If both "searchable" and "browsable" are true, the field shows up under "Metadata" in Library's grid filter.
     { version = 4, dataType="string", searchable=true, browsable=true, readOnly=true, id="wpid", title="WP-Id" },
     { version = 4, dataType="string", searchable=true, browsable=true, readOnly=true, id="upldate", title="Upload Date"      },
     { version = 4, dataType="string", searchable=true, browsable=true, readOnly=true, id="wpwidth", title="Width (full)"  },
     { version = 4,  dataType="string", searchable=true, browsable=true, readOnly=true, id="wpheight", title="Height (full)"  },
     { version = 4, dataType="url", searchable=true, browsable=true, readOnly=true, id="wpimgurl", title="WP Image url"  },
     { version = 4, dataType="string", searchable=true, browsable=true, readOnly=true, id="slug", title="Slug"  },
     { version = 4, dataType="url", searchable=true, browsable=true, readOnly=true, id="post", title="Post"  },
     { version = 4, dataType="string", searchable=true, browsable=true, id="gallery", title="Gallery"  },
     
    }
   }