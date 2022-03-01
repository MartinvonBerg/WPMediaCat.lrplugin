-- tagset for the plugin Metadata
-- Mind: Global 'PiName' and 'TagsetName' is defined in Info.lua

return {
    --title = LOC "$$$/WP_MediaCat2/Meta/TagsetTitle=WordPress-Meta",
    title = TagsetName,
    id = 'WpCatTagset1',

    items = {
        'com.adobe.filename',
        'com.adobe.copyname',
        'com.adobe.folder',
        'com.adobe.filesize',
        --'com.adobe.filetype',
        'com.adobe.dateTimeOriginal',
        'com.adobe.separator',
        -- bewertung
        -- beschriftung
        'com.adobe.title',
        { 'com.adobe.caption', height_in_lines = 3 },
        'com.adobe.comment',
        'com.adobe.separator',
        --'com.adobe.dateCreated',
        --'com.adobe.location',
        --'com.adobe.city',
        --'com.adobe.state',
        --'com.adobe.country',
        --'com.adobe.isoCountryCode',
        'com.adobe.GPS',
        'com.adobe.GPSAltitude',
        'com.adobe.separator',
        PiName .. '.wpid',
        PiName .. '.upldate',
        PiName .. '.wpwidth',
        PiName .. '.wpheight',
        PiName .. '.wpimgurl',
        PiName .. '.slug',
        PiName .. '.post',
        PiName .. '.gallery',
    }
}