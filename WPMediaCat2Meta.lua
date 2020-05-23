--PMediaCat2Meta
return {
    schemaVersion = 4, -- increment this value any time you make a change to the field definitions below
   
    metadataFieldsForPhotos = {
     
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