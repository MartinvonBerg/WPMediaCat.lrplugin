Preparation (prior to Installation)

!!! IMPORTANT !!!

- Backup Wordpress completely (including Database). If you don’t know how: Check google for that. There are great tutorials to find for that.

- Backup Lightroom Catalog (*.lrcat). If you don’t know how: Check google for that. There are great tutorials to find for that.

 

Installation of the Plugins

-        Wordpress-Plugin : Plugin-Tab -> Install -> Upload ZIP -> Install -> Activate –> Done. No Settings required. This is the Standard way for plugins given in ZIP-files.

-        Standard procedure for Lightroom-Plugins (see LR Documentation)

-        Settings: Go to the Publish-Settings of the Plugin

o   Name the Publish service to your needs.

o   Define the server settings and Test-it with the Button ‘Test Login’. If the test is not successful (e.g. wrong UID or PWD) the publishing will NOT work. The settings will be stored. Additionally the installation of the WP-Plugin will be tested. The test gives you a hint if not.

o   Hint on http versus https: Do NOT use the plugin with http-only. The UID or PWD are transferred unprotected via the net (Base64 can be easily decoded). Exception would be the use on a local machine with http://127.0.0.1/example.com

o   Choose whether to work in Test-Mode and / or in “Meta-Data-Mode” only. In Meta-Data-Mode, no images will be changed, only the Metadata of the image is updated. Test-Mode will work with a reduced amount of images and Log many debug-messages in the file WPCat2.log.

o   First-Sync-Settings: Choose whether to download unknown files to Lightroom and define which folder should be used. The images will be to the catalog and downloaded to the give folder. You can handle these images with LR also after the First-Sync.

o   Publish settings: Chose the standard settings you prefer. It is not recommended to choose an image size smaller than 2560 pixels.

 

Usage

-Wordpress: It is strongly recommended NOT to use the WP-Mediacatalog for editing any more. Edit / Add / Change / Update / Delete only with Lightroom after the first synchronization. The Catalog should be used for viewing and searching only. Nothing else. The usage of the created images in the catalog is identical to the standard usage in Wordpress.

 

-Lightroom

First Synchronization with Wordpress

Change “First Sync with WP” and wait for a while. Depending on the settings unknown images will be downloaded, stored and added to the LR-catalog. Existing images in non-Standard Sub-Folders will be added to (Sub-)Collections.

 

Later Synchronization

Select the intended images, choose the menu “re-publish” and do that. ALL settings and images in Wordpress will be overwritten! LR is the master! If you work with Metadata-Mode only the Metadata will be updated.

 

Collections

The WPCat-Standard Collection cannot be renamed. If you manage to do so, all synchronization will be lost.

New Collections will be stored in a separate subfolder in Wordpress under the …./uploads/<New Collection>. Sub-Collection will be stored in …./uploads/<New Collection>/<New Sub-Collection>/

 

Publishing: The publishing service can used like any other publish service in Lightroom. It is possible to add new, delete, edit metadata, edit development settings in Lightroom and upload these changes to Wordpress with the “Publish” Button in Lightroom. All Data is synchronized (except you change something in Wordpress and do not synchronize with LR after that. This is NOT a fully automated process.)

 

Updating of Plugins

No need to update for the moment

 

De-Installation of the Plugins

-        Deactivate, and delete Wordpress-Plugin. Nothing will be changed in the WP-database!

-        Standard procedure for Lightroom-Plugins (see LR Documentation) Nothing will be changed in the LR-database! The Metadata of the plugin will be restored in the LR-database for the case you come back later on.

 

Bugs

Unknown

 

License

GPL2

 

Liabality

None, you work on your own risk!