/* exported prefs */

/* Get the extension path. */
const _dpt_prefs_path = imports.misc.extensionUtils.getCurrentExtension()['path'] + '/prefs.js/';

/* Add the prefs.js files to the searchPath */
if (imports.searchPath.indexOf(_dpt_prefs_path) === -1) {
    imports.searchPath.unshift(_dpt_prefs_path);
}

/* Define prefs so that imports can find it. */
var prefs = imports.preferences.main;