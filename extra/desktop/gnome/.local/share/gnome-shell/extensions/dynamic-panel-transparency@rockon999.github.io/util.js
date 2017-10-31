/* exported get_shell_version, is_undef, clamp, is_valid, match_colors, remove_file, get_file, write_to_file, gdk_to_css_color, clutter_to_native_color, tuple_to_native_color, deep_freeze, strip_args */

const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;

/* This import can't be a constant as it requires lazy initialization. */
let Meta = null;

/* Gnome Versioning */
const MAJOR_VERSION = parseInt(imports.misc.config.PACKAGE_VERSION.split('.')[0], 10);
const MINOR_VERSION = parseInt(imports.misc.config.PACKAGE_VERSION.split('.')[1], 10);

/* Permission setting for created files. */
const PERMISSIONS_MODE = parseInt('0744', 8);

/* Utility Variable Access */

/**
 * Returns the current shell version.
 *
 * @returns {Object} The current shell version.
 *
 */
function get_shell_version() {
    return { major: MAJOR_VERSION, minor: MINOR_VERSION };
}

/* Utility Functions */

/**
 * Evaluates parameter 'value' and returns either 'value' or 'min'/'max' if 'value' is outside of the range.
 *
 * @param {Number} value - Test value.
 * @param {Number} min - Minimum value.
 * @param {Number} max - Maximum value.
 *
 * @returns {Number} 'value' or the minimum or maximum.
 *
 */
function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
}

/**
 * Determines if 'window' is a valid window to watch.
 * Will not work outside the extension code.
 *
 * @param {Object} window - Window to check.
 *
 * @returns {Boolean} Whether 'window' is a valid window to watch.
 *
 */
function is_valid(window) {
    if (!Meta) {
        Meta = imports.gi.Meta;
    }

    let windowTypes = [
        Meta.WindowType.NORMAL,
        Meta.WindowType.DIALOG,
        Meta.WindowType.MODAL_DIALOG,
        Meta.WindowType.TOOLBAR,
        Meta.WindowType.MENU,
        Meta.WindowType.UTILITY,
    ];

    let type = window.get_window_type();

    return (windowTypes.indexOf(type) !== -1);
}

/**
 * Retrieves the GFile for a file path.
 *
 * @param {string} file_path - Path for a file.
 *
 * @returns {Object} GFile for the path or null if the path is not valid.
 *
 */
function get_file(file_path) {
    try {
        let file = Gio.file_new_for_path(file_path);
        return file;
    } catch (error) {
        log(error);
        return null;
    }
}

/**
 * Write the given string to a file path; creating the necessary files and directories.
 *
 * @param {string} file_path - Path for a file.
 * @param {string} text - Text to write to the file.
 *
 * @returns {Boolean} Whether the file write was a success.
 *
 */
function write_to_file(file_path, text) {
    try {
        let file = get_file(file_path);
        let parent = file.get_parent();

        if (GLib.mkdir_with_parents(parent.get_path(), PERMISSIONS_MODE) === 0) {
            let success = file.replace_contents(text, null, false, Gio.FileCreateFlags.REPLACE_DESTINATION, null);
            return success[0];
        }
    } catch (error) {
        log('[Dynamic Panel Transparency] Error writing to file: ' + file_path);
        log(error);
    }

    return false;
}

/**
 * Deletes the given file_path.
 *
 * @param {string} file_path - Path for a file.
 *
 * @returns {Boolean} Whether the file deletion was a success.
 *
 */
function remove_file(file_path) {
    try {
        let file = get_file(file_path);
        let result = file.delete(null);
        return result;
    } catch (error) {
        log('[Dynamic Panel Transparency] Error removing file: ' + file_path);
        log(error);
    }

    return false;
}

/**
 * Converts a GdkColor into a JS/CSS color object.
 *
 * @param {Object} color - GdkColor to convert.
 *
 * @returns {Object} Converted RGB color.
 *
 */
function gdk_to_css_color(color) {
    let red = Math.round(clamp((color.red * 255), 0, 255));
    let green = Math.round(clamp((color.green * 255), 0, 255));
    let blue = Math.round(clamp((color.blue * 255), 0, 255));

    return { 'red': red, 'green': green, 'blue': blue };
}

/**
 * Converts a ClutterColor into a JS/CSS color object.
 *
 * @param {Object} color - ClutterColor to convert.
 * @param {Boolean} [alpha = false] - Whether to transfer the alpha value.
 *
 * @returns {Object} Converted RGB(A) color.
 *
 */
function clutter_to_native_color(color, alpha = false) {
    let output = { red: color.red, green: color.green, blue: color.blue };
    if (alpha) {
        output.alpha = color.alpha;
    }
    return output;
}

/**
 * Converts a tuple from a GVariant (typically) into a JS/CSS color object.
 *
 * @param {Object} color - Tuple to convert.
 * @param {Boolean} [alpha = false] - Whether to transfer the alpha value.
 *
 * @returns {Object} Converted RGB(A) color.
 *
 */
function tuple_to_native_color(tuple) {
    let color = { red: tuple[0], green: tuple[1], blue: tuple[2] };
    if (tuple.length === 4) {
        color.alpha = tuple[3];
    }
    return color;
}

/**
 * Compares two colors for equivalency.
 *
 * @param {Object} a - First color.
 * @param {Object} a - Second color.
 * @param {Boolean} [alpha = false] - Whether to check the alpha value.
 *
 * @returns {Boolean} Whether the two colors are equal.
 *
 */
function match_colors(a, b, alpha = false) {
    let result = (a.red === b.red);
    result = result && (a.green === b.green);
    result = result && (a.blue === b.blue);
    if (alpha) {
        result = result && (a.alpha === b.alpha);
    }
    return result;
}

/**
 * Freezes an Object's and its children.
 *
 * @param {Object} type - Object to freeze.
 * @param {Boolean} [recursive = false] - Whether to recursively traverse the object's children.
 *
 */
function deep_freeze(type, recursive = false) {
    const freeze_children = function(obj) {
        Object.keys(obj).forEach(function(value, index, arr) {
            if (typeof (value) === 'object' && !Object.isFrozen(value)) {
                Object.freeze(value);
                if (recursive) {
                    freeze_children(value);
                }
            }
        });
    };

    Object.freeze(type);
    freeze_children(type);
}

/**
 * Prevents any arguments from passing on.
 *
 * @param {Object} method - Method to call.
 *
 */
function strip_args(method) {
    return function() {
        method.call(this);
    };
}