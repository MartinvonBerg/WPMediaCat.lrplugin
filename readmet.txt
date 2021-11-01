TODO: update and rework as MD-file

Preparation (prior to Installation)

!!! IMPORTANT !!!

- Backup Wordpress completely (including Database). If you don’t know how: Check google for that. There are great tutorials to find for that.
- Backup Lightroom Catalog (*.lrcat). If you don’t know how: Check google for that. There are great tutorials to find for that.


Installation of the Plugins

-        Wordpress-Plugin : 
            1. Visit the plugins page on your Admin-page and click  ‘Add New’
            2. Search for 'wp_wpcat_json_rest', or 'JSON' and 'REST'
            1. Once found, click on 'Install'
            1. Go to the plugins page and activate the plugin

-        Standard procedure for Lightroom-Plugins (see LR Documentation or google)
-       Debuggin: Debug-messages are in the file WPCat2.log in your local Documents-directory.

Settings for LR-Plugin: Go to the Publish-Settings of the Plugin
    o   Name the Publish service to your needs.
    o   Wordpress Login Details and Settings
        - Login-Settings
        o   Define the server settings and Test it with the Button ‘Test Login’. If the test is not successful (e.g. wrong Login Name or Password) the publishing will NOT work. The settings will be stored. Additionally the installation of the WP-Plugin will be tested. The test gives you a hint if not.
        - Recommended Authorization with Wordpress 5.6:
            - Use WP REST application password + Basic auth
                The setting is only provided if run your website with https. So, use it only together with https (see above). 
            Process:
            - Login to your wordpress-site 
            - Go to Admin-Panel > User > Profile
            - Scroll down to "Application Passwords"
            - Provide a useful name for the application in the field underneath
            - Click the button "add new application password"
            - The new password will be shown. Copy it immediately and store it! It won't be shown again. Remove the spaces from the password.
            - Use the username of the admin and this Password in the http-header to access to wordpress 
        o   Hint on http versus https: Do NOT use the plugin with http-only. The UID or PWD are transferred unprotected via the net (Base64 can be easily decoded). Exception would be the use on a local machine with http://127.0.0.1/example.com

    o   Settings for (First)-Sync with Wordpress
        - Do local Copy: Check to download unknown photos to your local LR-catalog. If checked, proved a valid pathname. Use '\' only. The images will be added to the LR-catalog and downloaded to the given folder. You can handle these images with LR also after the First-Sync.
        - Only Do Metadata at first Sync: Only synchronize metadata if checked. If NOT, all images will be regenerated in WP.
        - First-SYNC Metadata handling: Choose whether LR --> WP or WP --> LR. All Data will be overwritten! So, backup first. 
    
    o   Select-Value-Settings for WP-Metadata
        - Choose the assignment of Metadata. Consistency checking is done not here but later on.

    o   Remaining Publish settings: Chose the standard settings you prefer. It is not recommended to choose an image size bigger than 2560 pixels. Because WP will NOT provide bigger images to the visitor (excep big_image_size_setting was changed in WP)

 

Usage

-Wordpress: It is strongly recommended NOT to use the WP-Media-Library for editing of JPG-images any more. Edit / Add / Change / Update / Delete only with Lightroom after the first synchronization. The Catalog should be used for viewing and searching only. Nothing else. The usage of the created images in the catalog is identical to the standard usage in Wordpress.
 

-Lightroom

First Synchronization with Wordpress
- Select the collection 'WPCat' (which can't renamed or deleted)
- Right-Click -> First-SYNC will be started. This takes a while
- After the First-SYNC the images are not published
    - remove alle PNGs, GIFs and other files that are NOT JPG
    - select from all catalog-images with multiple 'WPIDs' the one you want to use for synchronization.
- Depending on the settings unknown images will be downloaded, stored and added to the LR-catalog. 
- Existing images in non-Standard Sub-Folders will be added to (Sub-)Collections.

 
Later Synchronization

NOT IMPLEMENTED
 

Collections

The WPCat-Standard Collection cannot be renamed. If you manage to do so, all synchronization will be lost.

New Collections will be stored in a separate subfolder in Wordpress under the …./uploads/<New Collection>. Sub-Collection will be stored in …./uploads/<New Collection>/<New Sub-Collection>/

 
Publishing: 
The publishing service can used like any other publish service in Lightroom. It is possible to add new, delete, edit metadata, edit development settings in Lightroom and upload these changes to Wordpress with the “Publish” Button in Lightroom. All Data is synchronized (except you change something in Wordpress and do not synchronize with LR after that. This is NOT a fully automated process.)

 
Updating of Plugins

No need to update for the moment

 

De-Installation of the Plugins

-        Deactivate, and delete Wordpress-Plugin. Nothing will be changed in the WP-database!

-        Standard procedure for Lightroom-Plugins (see LR Documentation) Nothing will be changed in the LR-database! The Metadata of the plugin will be restored in the LR-database for the case you come back later on.

 

Bugs

First-SYNC is problematic. If many images are synchronized the many will be blocked.
Sometimes the synchronization of the catalog is too slow, so correctly images will be marked "to publish again". Select these images and set manually to 'up to date'.

 

License

private use only!

 

Liabality

None, you work on your own risk!