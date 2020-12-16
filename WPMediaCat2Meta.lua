--Definition der Metadaten für das Plug-in. Bei Änderungen muss die schemaversion hochgezählt werden!
return {
    schemaVersion = 8, -- increment this value any time you make a change to the field definitions below
   
    metadataFieldsForPhotos = {
     
     { version = 8, dataType="string", searchable=true, browsable=true, readOnly=false, id="wpid", title="WP-Id" },
     { version = 8, dataType="string", searchable=true, browsable=true, readOnly=false, id="upldate", title="Upload Date"      },
     { version = 8, dataType="string", searchable=true, browsable=true, readOnly=false, id="wpwidth", title="Width (full)"  },
     { version = 8,  dataType="string", searchable=true, browsable=true, readOnly=false, id="wpheight", title="Height (full)"  },
     { version = 8, dataType="url", searchable=true, browsable=true, readOnly=false, id="wpimgurl", title="WP Image url"  },
     { version = 8, dataType="string", searchable=true, browsable=true, readOnly=false, id="slug", title="Slug"  },
     { version = 8, dataType="url", searchable=true, browsable=true, readOnly=false, id="post", title="Post"  },
     { version = 8, dataType="string", searchable=true, browsable=true, readOnly=false, id="gallery", title="Gallery"  },
    }
   }