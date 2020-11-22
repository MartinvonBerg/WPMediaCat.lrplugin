--Definition der Metadaten für das Plug-in. Bei Änderungen muss die schemaversion hochgezählt werden!
return {
    schemaVersion = 6, -- increment this value any time you make a change to the field definitions below
   
    metadataFieldsForPhotos = {
     
     { version = 6, dataType="string", searchable=true, browsable=true, readOnly=true, id="wpid", title="WP-Id" },
     { version = 6, dataType="string", searchable=true, browsable=true, readOnly=true, id="upldate", title="Upload Date"      },
     { version = 6, dataType="string", searchable=true, browsable=true, readOnly=true, id="wpwidth", title="Width (full)"  },
     { version = 6,  dataType="string", searchable=true, browsable=true, readOnly=true, id="wpheight", title="Height (full)"  },
     { version = 6, dataType="url", searchable=true, browsable=true, readOnly=true, id="wpimgurl", title="WP Image url"  },
     { version = 6, dataType="string", searchable=true, browsable=true, readOnly=false, id="slug", title="Slug"  },
     { version = 6, dataType="url", searchable=true, browsable=true, readOnly=true, id="post", title="Post"  },
     { version = 6, dataType="string", searchable=true, browsable=true, readOnly=true, id="gallery", title="Gallery"  },
     --{ version = 6, dataType="string", searchable=false, browsable=false, readOnly=true, id="order", title="Sort-Order"  }, 
    }
   }