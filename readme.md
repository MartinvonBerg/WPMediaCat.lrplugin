# Overview
This Lightroom Plugin is a publishing service for WordPress. Lightroom is used as a 'headless' editor for WordPress. All image work with metadata etc. is done in Lightroom. Publish your images to WordPress in one click and update or change whatever you want. This is always done with the same WordPress image. No need to change posts or pages anymore, if you changed something for the image, e.g. title or development settings like cropping or whatever. You may even update the Image alt_text and the caption in ALL posts and pages using that image!.

# Preparation (prior to Installation)

**! IMPORTANT !**

-     Backup WordPress completely (including Database). If you don’t know how to do: Check google for that. There are great tutorials to find for that.
-     Backup Lightroom Catalog (*.lrcat). If you don’t know how: Check google for that. There are great tutorials to find for that.


# Installation of the Plugins

## Required WordPress-Plugin: 
        1. Visit the plugins page on your WordPress Admin-page and click  ‘Add New’
        2. Search for 'wp_wpcat_json_rest' by Martin von Berg
        3. Once found, click on 'Install'
        4. Go to the plugins page and activate the plugin

## Required Lightroom-Plugin:
        See Lightroom Documentation or google how to install a plugin. Shortform:
        - Download the package or the whole from project from github
        - Unpack everythin to a folder on your machine
        - Open the Plug-in-Manger from Lightroom and navigate to the folder
        - Add this folder, activate and done
# Debugging (optional):
- Debugging messages could be found in the file WP_MediaCat3.log in your local Documents-directory.
### How to Switch-Off all Debugging messages in the file WP_MediaCat3.log
- Open the File `PluginGlobals.lua` and change the following line from 'true' to 'false' or vice versa. (wihtout quotes!)
```lua
logDebug = true -- or false
```
- Store the file `PluginGlobals.lua`

# Plugin Settings
## Manual changes in Files
No need to change anything. If you like to change the Quality of the (optional) Webp-Conversion, you can do that:
 - Open the File `PluginGlobals.lua` and change the following line
```lua
webquality = '40' -- must be a string! Any value between 1 and 100 should be OK.
```
- Mind that with a quality higher than 40 the webp-files will get rather big.
- Store this file `PluginGlobals.lua`

## Standard Settings the Plugin in Lightroom:
This is a standard procedure as with any other Publishing Plugin of Lightroom. 

![setting1](./images/pisett1.jpg)

Double Click on the Publish Service "WP_MediaCat.." shown here above in light grey. The following window will show up. All Settings have to be done under the two top-most tabs.

![setting2](./images/pisett2.jpg)

First Tab `Publish service` Choose any name you like for the description.

Second Tab `WordPress Login Details and Settings:`

- Login-Settings
    - Site URL: Provide the complete URL to your WordPress-Site as shown in the above image.
    - Login Name and Login Password have to be prepared in the Admin-Panel of WordPress.
         - Process:
            - Login to your wordpress-site 
            - Go to Admin-Panel > User > Profile
            - Enter the User login-name that you are currently editing to `Login Name`
            - Scroll down to "Application Passwords". The setting is only provided if run your website with https. So, use it only together with https.
            - Provide a useful name for the application in the field underneath
            - Click the button "add new application password"
            - The new password will be shown. Copy it immediately and store it in `Login Password`! It won't be shown again!
             
            - Hint on http versus https: Do NOT use the plugin with http-only. The User-Name and Password are transferred unprotected via the net (Base64 can be easily decoded). Exception would be the use on a local machine with e.g. http://127.0.0.1/example.com. **But, it is safe to use it with https!**

    - Test the Login with the Button `Test Login`. If the test is not successful (e.g. wrong Login Name or Password) it will not be possible to safe these settings. Additionally the installation of the WP-Plugin will be tested. The test gives you some hints. **BUT** that means that this Button has to be pressed every time you wish to change anything. 
    
    - Optional: Settings for File Upload (Webp-Conversion)
        - Check if you wish to convert the files from jpg to webp prior to upload. This is only available if ImageMagick is installed on your machine. Check webpage of ImageMagick for the installation procedure on macOS or Windows.
        - **macOS** Copy the binary `magick`into the folder where you copied this Lightroom plugin.  

    - Settings for (First)-Sync with WordPress
        - Do local Copy: Check to download unknown photos to your local Lightroom-catalog. If checked, provide a complete valid path. Use '\' only on Win and '/' only on macOS. The images will be added to the LR-catalog and downloaded to the given folder. You can handle these images with LR also after the First-Sync like any other image. 
        - Only Do Metadata at first Sync: Only synchronize metadata if checked. If NOT, all images will be regenerated in WP.
        - First-SYNC Metadata handling: Choose whether to write from LR to WP or from WP to LR. All Metadata will be overwritten! So, backup first, if you are in test-mode.
    
    - Select-Value-Settings for WP-Metadata
        - Choose the assignment of Metadata. There is **NO** Consistency checking done. From Lightroom only the title and caption are used for Metadata. On the other hand WordPress uses four fields for Metadata: title, alt_text, caption and description. The titles are always mapped. For the mapping of the others you may use this settings.
        - Update Caption for all Images with LR caption. Only for Gutenberg!
            The WordPress Plugin that you installed provides a function to update all pages and posts that are using the image. This is done **ALWAYS** for the alt_text (used for SEO). Optionally it could be done for the caption, too. **BUT** all captions on all pages and posts using the same image will be identical after that! So, if you are using context-dependant captions you should **NOT** activate this setting. Works only with Gutenberg: image, gallery, and image-with-text.

    - Remaining Standard Publish settings like with any other publishing service
        - Chose the other settings you prefer. It is not recommended to choose an image size bigger than 2560 pixels because WP will NOT provide bigger images to the visitor (except big_image_size_setting was changed in WordPress)

**FINALLY** save all the settings.

 

# Usage
    Note on WordPress: It is strongly recommended NOT to use the WP-Media-Library for editing of JPG-images any more. Edit / Add / Change / Update / Delete only with Lightroom after the first synchronization. The Catalog should be used for viewing and searching only. Nothing else. The usage of the created images in the catalog is identical to the standard usage in WordPress.

## (Optional) First Synchronization with WordPress
- Select the collection 'WPCat' (which can't be renamed or deleted)
- Right-Click -> Select the entry First-SYNC... (second from the bottom)

![firstsync](./images/firstsync.jpg)

- The synchronization will be started. This may take a while ...
Depending on the settings unknown images will be downloaded, stored and added to the LR-catalog. 
- Existing images in non-Standard WordPress-Folders will be added to (Sub-)Collections, like you can see in the image above.
- The quality of the search process depends on your Lighroom catalog. I have several files with 'test.jpg' or 'noname.jpg' or copies of identical files several times it will be impossible to decide. It's not possible to decide which file was originally uploaded to WordPress. You have to do so with a manual process. Therefore:
- After the First-SYNC the images are not published 
- Select right images manually
    - remove alle GIFs and other files that are NOT JPG-Files. Keep the PNGs if you like that. But: PNGs will be converted to JPGs later on, if you DID NOT decide to use wepb. If you are not sure, remove PNGs, too.
    - select from all catalog-images with identical 'WPIDs' the one image you want to use for synchronization. This might be done with the metadata panel. You have to show up the WordPress-ID in the panel an check wether there are entries with more than one for each WordPress-ID.
    - Example: The ID 5196 was set 4 times, because I have 4 files with 'unbenannt-1.jpg'. Great!
    ![multiples](./images/multiples.jpg)
- Finally Publish all Images again to WordPress. You can chose to do that for the Metadata only, see settings.And decide wether to write from WP to LR or vice versa. That is a bit annoying but required. You might also overwrite **ALL** existing images in WordPress! 
- Done with first Synchronization

## Later Synchronization

It is possible to reload the Metadata 'title', 'caption', 'description' and 'alt_text' from WordPress and write it to Lightroom. You may do that if you changed values directly in the WordPress Media Library. This is only possible for published Photos. It's done with the following process:
- Select one ore more photos
- Go to the Library Menu of Lightroom and select the following entry
![resync](./images/resync.jpg)
- Re-Synchronisation will start and overwrite title and caption on Lightroom.


## Collections

    HINT: The Standard Collection WPCat cannot be renamed. If you manage to do so by hacking or whatever, all synchronization will be lost.

The usage of collections and collection sets is like with any other publishing plugin of Lightroom. Check the LR manual for that. A collection and collection set will correspond to a folder in your WordPress upload folder! Meaning that **NOT** the WordPress standard folder is used (except you add images to 'WPCat') but a folder that is named according to your collection. This is useful if you want to filter images by folder (= Gallery) or organize the WP-upload folder. **You can even use this folder to create a nice WordPress-Image-Gallery with my WordPress-Gallery-Plugin, see here: https://github.com/MartinvonBerg/Fotorama-Leaflet-Elevation**


    EXCEPTION I: It is not possible to simply move a collection. If you like so, store the images you like to move in a smart collection. Delete the 'old' collection. Add the new collection at the new place. Add images from the smart collection to the new collection and publish all.

    EXCEPTION II: It is not possible to simply move an already published image. I didn't see any advantage to publish the same image more than once. If you like to do so create a virtual copy and publish this one. Background: If it is necessary to publish a photo more than once you might probably change metadata or development settings, so it is useful to use a virtual copy.

 
## Publishing
The publishing service can used like any other publish service in Lightroom. It is possible to add new, delete, edit metadata, edit development settings in Lightroom and upload these changes to WordPress with the “Publish” Button in Lightroom. All Data is synchronized (except you change something in WordPress and do not synchronize with LR after that. This is NOT a fully automated process.)

## Working with Metadata
- It is possible to select and search with the Metadata of the Plugin. Use the Metadata panel for that like shown here for the WordPress-ID.
![multiples](./images/multiples.jpg)
- You may restrict the currently shown metadata for one image to relevant data for the plugin

![metaselect](./images/metaselect.jpg)
- The small arrow right to the Image Link will guide you directly to the image in you WordPress Admin Panel (provided you are logged in).

## Generate WordPress Code for Gutenberg
- Select on image - Right Click - Menu Opens - Select the third entry from the bottom
- The correct Gutenberg Code for wp-image is copied to your clipboard.
- Just paste this code to your page / post and you are done with adding an image!
- There is some overhead which you unfortunately have to delete.

 
# Updating of Plugins

No need to update at the moment
 

# De-Installation of the Plugins

- Deactivate, and delete WordPress-Plugin. Nothing will be changed in the WP-database!

- Standard procedure for Lightroom-Plugins (see LR Documentation) Nothing will be changed in the LR-database! The Metadata of the plugin will be restored in the LR-database for the case you come back later on.

# SPECIAL: Create further instancies of the Plugin to work with several websites

ONLY recommende if you know what you are doing. You need to copy directories, rename them and work within the files of the plugin. Optional but highly recommended: Backup your LR database
1. Create a new directory under the directory where your plugin #1 already resides.
2. Name this new dir to 'plugin2.lrdevplugin' or 'plugin2.lrplugin'.
    IMPORTANT: Always use 'lrdevplugin' or 'lrplugin' after a dot at the end of the folder name!
3. Required changes in files:

    3.1. Change in Info.lua the string for variable 'PiName' to something like 'com.plugin2.wordpress.....' different to the one in plugin1.

    3.2. Change in Info.lua the string for variable 'TagsetName' to something like 'WP-Meta2' different to the one in plugin1.

    3.3. Do the same in the file 'PluginGlobals.lua'

    3.4. Store these all these files

4. Load and activate the 'new' plugin in LR from the folder of Step 2.
5. Define the settings for that copy of the plugin to your 2nd / 3rd / ... WordPress site.
6. Done.


# Bugs and TODOs

- First-SYNC is problematic and performance dependant. If many images are synchronized LR will be blocked for a long time.
- Sometimes the synchronization of the catalog is too slow, so correctly published images will be marked "to publish again". Select these images and set manually to 'up to date'.
- TODO: Translation is not finalized yet.

 
# License

private use only!

# Liability

This is a private project from one person working in a full-time job as system engineer. If you need support you couldn't expect me to respond in hours. If you need a high quality, full-blown Lightroom Plugin I recommend to use this: https://meowapps.com/plugin/wplr-sync/ . I can't give any Liability promises, you work on your own risk! Always backup!

# Testing
No unit testing at all. Only did overall system test on two machines, see below. The result was tested on three different websites (local, staging and productive)
## Windos
Test with LR 6.14 and LR 11.0.0 under Windows 10 21H0.
## macOS
Test with LR 11.0.0 under bigSUR 11.6.1.

# Sponsoring
Any welcome use the donate button for that. The development took me hundreds of hours.

# Credits
- ZeroBrane Studio for Lua Debugging, https://studio.zerobrane.com/
- inspect.lua by Enrique García Cota, https://github.com/kikito/inspect.lua
- Require.lua by John R. Ellis and very helpful hints from him in the Adobe Community, https://johnrellis.com/lightroom/debugging-toolkit.htm Thank you very much for you help!
- simplecsv.lua probably from here: https://nocurve.com/2014/03/05/simple-csv-read-and-write-using-lua/