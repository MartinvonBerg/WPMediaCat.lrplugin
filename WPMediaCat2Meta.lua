--Definition der Metadaten für das Plug-in. Bei Änderungen muss die schemaversion hochgezählt werden!
return {
    schemaVersion = 7, -- increment this value any time you make a change to the field definitions below
   
    metadataFieldsForPhotos = {
     
     { version = 7, dataType="string", searchable=true, browsable=true, readOnly=true, id="wpid", title="WP-Id" },
     { version = 7, dataType="string", searchable=true, browsable=true, readOnly=true, id="upldate", title="Upload Date"      },
     { version = 7, dataType="string", searchable=true, browsable=true, readOnly=true, id="wpwidth", title="Width (full)"  },
     { version = 7,  dataType="string", searchable=true, browsable=true, readOnly=true, id="wpheight", title="Height (full)"  },
     { version = 7, dataType="url", searchable=true, browsable=true, readOnly=true, id="wpimgurl", title="WP Image url"  },
     { version = 7, dataType="string", searchable=true, browsable=true, readOnly=false, id="slug", title="Slug"  },
     { version = 7, dataType="url", searchable=true, browsable=true, readOnly=true, id="post", title="Post"  },
     { version = 7, dataType="string", searchable=true, browsable=true, readOnly=true, id="gallery", title="Gallery"  },
     --{ version = 7, dataType="string", searchable=false, browsable=false, readOnly=true, id="order", title="Sort-Order"  }, 
    }
   }