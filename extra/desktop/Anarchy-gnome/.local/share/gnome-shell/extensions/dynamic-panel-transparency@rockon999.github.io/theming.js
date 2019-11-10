/* exported init, cleanup, remove_maximized_background_color, remove_unmaximized_background_color, set_maximized_background_color, set_unmaximized_background_color, remove_background_color, set_theme_background_color, set_theme_opacity, get_theme_opacity, get_theme_background_color, register_text_shadow, add_text_shadow, register_icon_shadow, add_icon_shadow, has_text_shadow, has_icon_shadow, remove_text_shadow, remove_icon_shadow, register_text_color, set_text_color, remove_text_color, set_panel_color, set_corner_color, clear_corner_color, get_background_image_color, get_background_color, get_maximized_opacity, get_unmaximized_opacity, strip_panel_styling, reapply_panel_styling, strip_panel_background_image, reapply_panel_background_image, strip_panel_background, reapply_panel_background, set_background_alpha */

const St = imports.gi.St;

const Main = imports.ui.main;

const Me = imports.misc.extensionUtils.getCurrentExtension();
const Params = imports.misc.params;

const Settings = Me.imports.settings;
const Util = Me.imports.util;

const GdkPixbuf = imports.gi.GdkPixbuf;

/* Convenience constant for the shell panel. */
const Panel = Main.panel;

/* Constants for theme opacity detection. */
const THEME_OPACITY_THRESHOLD = 50;

/* Constants for color averaging. */
const SATURATION_WEIGHT = 1.5;
const WEIGHT_THRESHOLD = 1.0;
const ALPHA_THRESHOLD = 24;

/* Scale factor for color conversion. */
const SCALE_FACTOR = 255.9999999;

/**
 * @typedef {Object} Color - Represents a standard color object
 * @property {number} red - Red value ranging from 0-255.
 * @property {number} green - Green value ranging from 0-255.
 * @property {number} blue - Blue value ranging from 0-255.
 * @property {number} [alpha=1.0] - Alpha value ranging from 0-1.0 with support for two decimal places.
 */

/**
 * Intialize.
 *
 */
function init() {
    this.stylesheets = [];
    this.styles = [];

    this.background_styles = [];

    _updatePanelCSS();
}

/**
 * Used to release any held assets of theming.
 *
 */
function cleanup() {
    let theme = St.ThemeContext.get_for_stage(global.stage).get_theme();

    for (let style of this.styles) {
        Panel.actor.remove_style_class_name(style);
    }

    for (let style of this.background_styles) {
        Panel.actor.remove_style_class_name(style);
    }

    for (let sheet of this.stylesheets) {
        theme.unload_stylesheet(Util.get_file(sheet));
        Util.remove_file(sheet);
    }

    this.background_styles = null;
    this.stylesheets = null;
    this.styles = null;
}

/**
 * Sets the theme background color.
 *
 * @param {Color} color - Object representing an RGBA color.
 */
function set_theme_background_color(color) {
    this.theme_background_color = color;
}

/**
 * Gets the theme opacity.
 *
 * @returns {Number} alpha - Alpha value ranging from 0-255.
 */
function get_theme_opacity() {
    return this.theme_opacity;
}

/**
 * Gets the theme background color.
 *
 * @returns {Object} color - Object representing an RGBA color.
 */
function get_theme_background_color() {
    return this.theme_background_color;
}

/**
 * Sets the theme opacity.
 *
 * @param {Number} alpha - Alpha value ranging from 0-255.
 */
function set_theme_opacity(alpha) {
    this.theme_opacity = alpha;
}
/**
 * Registers a shadow stylesheet for text in the panel.
 *
 * @param {Color} text_color - Object representing an RGBA color.
 * @param {Number[]} text_position - Integer array containing horizontal offset, vertical offset, radius. (in that order)
 */
function register_text_shadow(text_color, text_position) {
    let text_color_css = 'rgba(' + text_color.red + ', ' + text_color.green + ', ' + text_color.blue + ', ' + text_color.alpha.toFixed(2) + ')';
    let text_position_css = '' + text_position[0] + 'px ' + text_position[1] + 'px ' + text_position[2] + 'px';

    register_style('dpt-panel-text-shadow');

    return apply_stylesheet_css('.dpt-panel-text-shadow .panel-button { text-shadow: ' + text_position_css + ' ' + text_color_css + '; }', 'foreground/panel-text-shadow');
}

/**
 * Adds the currently registered shadow stylesheet to the text in the panel.
 *
 * @param {Color} text_color - Object representing an RGBA color.
 * @param {Number[]} text_position - Integer array containing horizontal offset, vertical offset, radius. (in that order)
 */
function add_text_shadow() {
    Panel.actor.add_style_class_name('dpt-panel-text-shadow');
}

/**
 * Register a shadow stylesheet for icons in the panel.
 *
 * @param {Color} icon_color - Object representing an RGBA color.
 * @param {Number[]} icon_position - Integer array containing horizontal offset, vertical offset, radius. (in that order)
 */
function register_icon_shadow(icon_color, icon_position) {
    let icon_color_css = 'rgba(' + icon_color.red + ', ' + icon_color.green + ', ' + icon_color.blue + ', ' + icon_color.alpha.toFixed(2) + ')';
    let icon_position_css = '' + icon_position[0] + 'px ' + icon_position[1] + 'px ' + icon_position[2] + 'px';

    let stylesheet = apply_stylesheet_css('.dpt-panel-icon-shadow .system-status-icon { icon-shadow: ' + icon_position_css + ' ' + icon_color_css + '; }\n.dpt-panel-arrow-shadow .popup-menu-arrow { icon-shadow: ' + icon_position_css + ' ' + icon_color_css + '; }', 'foreground/panel-icon-shadow');

    register_style('dpt-panel-icon-shadow');
    register_style('dpt-panel-arrow-shadow');

    return stylesheet;
}

/**
 * Adds the currently register shadow stylesheet to icons in the panel.
 *
 */
function add_icon_shadow() {
    Panel.actor.add_style_class_name('dpt-panel-icon-shadow');
    Panel.actor.add_style_class_name('dpt-panel-arrow-shadow');
}

/**
 * Determines if the panel currently has text shadowing applied.
 *
 * @returns {Boolean} If the panel has text shadowing.
 */
function has_text_shadow() {
    return Panel.actor.has_style_class_name('dpt-panel-text-shadow');
}

/**
 * Determines if the panel currently has icon shadowing applied.
 *
 * @returns {Boolean} If the panel has icon shadowing.
 */
function has_icon_shadow() {
    return (Panel.actor.has_style_class_name('dpt-panel-icon-shadow') || Panel.actor.has_style_class_name('dpt-panel-arrow-shadow'));
}

/**
 * Removes any text shadowing; deregistering the stylesheet and removing the css.
 *
 */
function remove_text_shadow() {
    Panel.actor.remove_style_class_name('dpt-panel-text-shadow');
}

/**
 * Removes any icon shadowing; deregistering the stylesheet and removing the css.
 *
 */
function remove_icon_shadow() {
    Panel.actor.remove_style_class_name('dpt-panel-icon-shadow');
    Panel.actor.remove_style_class_name('dpt-panel-arrow-shadow');
}

/**
 * Registers text & icon coloring.
 *
 * @param {Color} color - Object containing an RGB color value.
 * @param {string} prefix - What prefix to apply to the stylesheet. '-' is the default.
 */
function register_text_color(color, prefix) {
    let color_css = 'color: rgb(' + color.red + ', ' + color.green + ', ' + color.blue + ');';

    if (prefix) {
        prefix = '-' + prefix + '-';
    } else {
        prefix = '-';
    }

    let stylesheet = apply_stylesheet_css('.dpt-panel' + prefix + 'text-color .panel-button { ' + color_css + ' }\n.dpt-panel' + prefix + 'icon-color .system-status-icon { ' + color_css + ' }\n.dpt-panel' + prefix + 'arrow-color .popup-menu-arrow { ' + color_css + ' }', 'foreground/panel' + prefix + 'text-color');

    register_style('dpt-panel' + prefix + 'text-color');
    register_style('dpt-panel' + prefix + 'icon-color');
    register_style('dpt-panel' + prefix + 'arrow-color');

    return stylesheet;
}

/**
 * Sets which registered text color stylesheet to use for the text coloring. @see register_text_color
 *
 * @param {string} prefix - What stylesheet prefix to retrieve. '-' is the default.
 */
function set_text_color(prefix) {
    if (prefix) {
        prefix = '-' + prefix + '-';
    } else {
        prefix = '-';
    }

    Panel.actor.add_style_class_name('dpt-panel' + prefix + 'text-color');
    Panel.actor.add_style_class_name('dpt-panel' + prefix + 'icon-color');
    Panel.actor.add_style_class_name('dpt-panel' + prefix + 'arrow-color');
}

/**
 * Remove a registered text color stylesheet from the panel. @see set_text_color
 *
 * @param {string} prefix - What stylesheet prefix to retrieve. '-' is the default.
 */
function remove_text_color(prefix) {
    if (prefix) {
        prefix = '-' + prefix + '-';
    } else {
        prefix = '-';
    }

    Panel.actor.remove_style_class_name('dpt-panel' + prefix + 'text-color');
    Panel.actor.remove_style_class_name('dpt-panel' + prefix + 'icon-color');
    Panel.actor.remove_style_class_name('dpt-panel' + prefix + 'arrow-color');
}

/**
 * Registers any custom style so that it can be removed when the extension is disabled.
 *
 * @param {string} style - The name of a CSS styling.
 */
function register_style(style) {
    if (this.styles.indexOf(style) === -1) {
        this.styles.push(style);
    }
}

/**
 * Set's the panel corners' actors to a specific background color.
 *
 * @param {Color} color [color={}] - Object containing an RGBA color value.
 */
// TODO: Gnome needs CSS styling for the corners.
function set_corner_color(color) {
    let panel_color = { red: 0, green: 0, blue: 0 };

    if (typeof (Settings.get_panel_color) !== 'undefined' && Settings.get_panel_color !== null) {
        panel_color = get_background_color();
    }

    color = Params.parse(color, {
        red: panel_color.red,
        green: panel_color.green,
        blue: panel_color.blue,
        alpha: 0
    });

    let opacity = Util.clamp(color.alpha / SCALE_FACTOR, 0, 1).toFixed(2);

    /* I strongly dislike using a deprecated method (set_style)
     * but this is a hold over from the older extension code and
     * the only way to keep per-app coloring working with corners. */
    let coloring = '-panel-corner-background-color: rgba(' + color.red + ', ' + color.green + ', ' + color.blue + ', ' + opacity + ');' +
        '' + '-panel-corner-border-color: transparent;';

    // TODO: Update this code. We're using @deprecated code.
    Panel._leftCorner.actor.set_style(coloring);
    Panel._rightCorner.actor.set_style(coloring);
}

/**
 * Removes any corner styling this extension has applied.
 *
 */
function clear_corner_color() {
    Panel._leftCorner.actor.set_style(null);
    Panel._rightCorner.actor.set_style(null);
}

/**
 * Gets the RGBA color of the background/border image in a theme.
 *
 * @param {Object} theme - An st-theme-node to retrieve the color from.
 *
 * @returns {Object} RGBA color retrieved from the theme node.
 */
function get_background_image_color(theme) {
    let file = theme.get_background_image();

    if (!file) {
        log('[Dynamic Panel Transparency] No background image found in user theme.');

        let image = theme.get_border_image();

        if (!image) {
            log('[Dynamic Panel Transparency] No border image found in user theme.');
            return null;
        } else {
            file = image.get_file();
        }
    }

    try {
        let background = GdkPixbuf.Pixbuf.new_from_file(file.get_path());

        if (!background) {
            log('[Dynamic Panel Transparency] Provided background is invalid.');
            return null;
        }
        return average_color(background);
    } catch (error) {
        log('[Dynamic Panel Transparency] Could not load the background and/or border image for your theme.');
        log(error);
        return null;
    }

}

/**
 * Returns the user's desired panel color from Settings. Handles theme detection again.
 * DEPENDENCY: Settings
 * TODO: Remove legacy backend code.
 *
 * @returns {Object} Object containing an RGBA color value.
 */
function get_background_color() {
    let custom = Settings.get_panel_color({ app_info: true });

    if (custom.app_info !== null && Settings.check_overrides()) {
        if (Settings.window_settings_manager['enable_background_tweaks'][custom.app_info] || Settings.app_settings_manager['enable_background_tweaks'][custom.app_info]) {
            return custom.value;
        } else {
            if (!Settings.enable_custom_background_color()) {
                return this.theme_background_color;
            }

            let original = Settings.get_panel_color({ app_settings: false });
            return original;
        }
    }

    if (!Settings.enable_custom_background_color()) {
        return this.theme_background_color;
    } else {
        return custom.value;
    }
}

/**
 * Returns the user's desired maximized panel opacity from Settings or their theme.
 * DEPENDENCY: Settings
 * TODO: Needs better system to determine when default theme opacities are too low.
 *
 * @returns {Number} Alpha value from 0-255.
 */
function get_maximized_opacity() {
    let maximized_opacity = Settings.get_maximized_opacity({ app_info: true });

    /* 1) Make sure we want a custom opacity. */
    /* 2) If custom.app_info !== null that means the setting is overriden. */
    if (maximized_opacity.app_info !== null && Settings.check_overrides()) {
        if (Settings.window_settings_manager['enable_background_tweaks'][maximized_opacity.app_info] || Settings.app_settings_manager['enable_background_tweaks'][maximized_opacity.app_info]) {
            return maximized_opacity.value;
        }
    }

    if (!Settings.enable_custom_opacity()) {
        if (this.theme_opacity >= THEME_OPACITY_THRESHOLD) {
            return this.theme_opacity;
        } else if (this.theme_opacity === 0) {
            /* Get the default value if the theme already added transparency */
            return Settings.get_maximized_opacity({ default: true });
        } else {
            return THEME_OPACITY_THRESHOLD;
        }
    } else {
        return maximized_opacity.value;
    }
}

/**
 * Returns the user's desired unmaximized panel opacity from Settings or their theme.
 * DEPENDENCY: Settings
 *
 * @returns {Number} Alpha value from 0-255.
 */
function get_unmaximized_opacity() {
    if (Settings.enable_custom_opacity()) {
        return Settings.get_unmaximized_opacity();
    } else {
        return Settings.get_unmaximized_opacity({ default: true });
    }
}

/**
 * Applies the style class 'panel-effect-transparency' and removes the basic CSS preventing this extension's transitions.
 *
 */
function strip_panel_styling() {
    Panel.actor.add_style_class_name('panel-effect-transparency');
}

/**
 * Removes the style class 'panel-effect-transparency' and enables the stock CSS preventing this extension's transitions.
 *
 */
function reapply_panel_styling() {
    Panel.actor.remove_style_class_name('panel-effect-transparency');
}

/**
 * Applies the style class 'panel-background-image-transparency' and removes the basic CSS preventing this extension's transitions.
 *
 */
function strip_panel_background_image() {
    Panel.actor.add_style_class_name('panel-background-image-transparency');
}

/**
 * Removes the style class 'panel-background-image-transparency' and enables the stock CSS preventing this extension's transitions.
 *
 */
function reapply_panel_background_image() {
    Panel.actor.remove_style_class_name('panel-background-image-transparency');
}

/**
 * Applies the style class 'panel-background-color-transparency' and removes any CSS embellishments.
 */
function strip_panel_background() {
    Panel.actor.add_style_class_name('panel-background-color-transparency');
}

/**
 * Reapplies the style class 'panel-background-color-transparency' and enables any CSS embellishments.
 *
 */
function reapply_panel_background() {
    Panel.actor.remove_style_class_name('panel-background-color-transparency');
}

/**
 * Writes CSS data to a file and loads the stylesheet into the Shell.
 *
 * @param {string} css - CSS data.
 * @param {string} name - Name of the intended CSS stylesheet.
 *
 * @returns {string} Filename of the stylesheet.
 */
function apply_stylesheet_css(css, name) {
    let file_name = Me.dir.get_path() + '/styles/' + name + '.dpt.css';
    /* Write to the file. */
    if (!Util.write_to_file(file_name, css)) {
        log('Dynamic Panel Transparency does not have write access to its own directory. Dynamic Panel Transparency cannot be installed as a system extension.');
        return null;
    }
    let theme = St.ThemeContext.get_for_stage(global.stage).get_theme();

    // COMPATIBILITY: st-theme used strings, not file objects in 3.14
    if (theme.load_stylesheet(Util.get_file(file_name))) {
        this.stylesheets.push(file_name);
    } else {
        log('[Dynamic Panel Transparency] Error Loading Temporary Stylesheet: ' + name);
        return null;
    }

    return file_name;
}

/**
 * Taken from Plank. Used to calculate the average color of a theme's images.
 * src: http://bazaar.launchpad.net/~docky-core/plank/trunk/view/head:/lib/Drawing/DrawingService.vala
 *
 * @param {Object} source - A Gtk.Pixbuf
 */
function average_color(source, width, height) {
    let r, g, b, a, min, max;
    let delta;

    let rTotal = 0.0;
    let gTotal = 0.0;
    let bTotal = 0.0;

    let bTotal2 = 0.0;
    let gTotal2 = 0.0;
    let rTotal2 = 0.0;
    let aTotal2 = 0.0;

    let dataPtr = source.get_pixels();

    width = (typeof (width) === 'undefined' || width === null) ? source.get_width() : width;
    height = (typeof (height) === 'undefined' || height === null) ? source.get_height() : height;

    let length = width * height;

    let scoreTotal = 0.0;

    for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {

            /* eslint-disable */

            let i = y * width * 4 + x * 4;

            r = dataPtr[i];
            g = dataPtr[i + 1];
            b = dataPtr[i + 2];
            a = dataPtr[i + 3];

            /* eslint-enable */

            // skip (nearly) invisible pixels
            if (a <= ALPHA_THRESHOLD) {
                length--;
                continue;
            }

            min = Math.min(r, Math.min(g, b));
            max = Math.max(r, Math.max(g, b));
            delta = max - min;

            // prefer colored pixels over shades of grey
            let score = SATURATION_WEIGHT * (delta === 0 ? 0.0 : delta / max);

            // weighted sums, revert pre-multiplied alpha value
            bTotal += score * b / a;
            gTotal += score * g / a;
            rTotal += score * r / a;
            scoreTotal += score;

            // not weighted sums
            bTotal2 += b;
            gTotal2 += g;
            rTotal2 += r;
            aTotal2 += a;
        }
    }

    // looks like a fully transparent image
    if (length <= 0) {
        return { red: 0, green: 0, blue: 0, alpha: 0 };
    }

    scoreTotal /= length;
    bTotal /= length;
    gTotal /= length;
    rTotal /= length;

    if (scoreTotal > 0.0) {
        bTotal /= scoreTotal;
        gTotal /= scoreTotal;
        rTotal /= scoreTotal;
    }

    bTotal2 /= length * 255;
    gTotal2 /= length * 255;
    rTotal2 /= length * 255;
    aTotal2 /= length * 255;

    // combine weighted and not weighted sum depending on the average "saturation"
    // if saturation isn't reasonable enough
    // s = 0.0 -> f = 0.0 ; s = WEIGHT_THRESHOLD -> f = 1.0
    if (scoreTotal <= WEIGHT_THRESHOLD) {
        let f = 1.0 / WEIGHT_THRESHOLD * scoreTotal;
        let rf = 1.0 - f;
        bTotal = bTotal * f + bTotal2 * rf;
        gTotal = gTotal * f + gTotal2 * rf;
        rTotal = rTotal * f + rTotal2 * rf;
    }

    // there shouldn't be values larger then 1.0
    let max_val = Math.max(rTotal, Math.max(gTotal, bTotal));
    if (max_val > 1.0) {
        bTotal /= max_val;
        gTotal /= max_val;
        rTotal /= max_val;
    }

    rTotal = Math.round(rTotal * 255);
    gTotal = Math.round(gTotal * 255);
    bTotal = Math.round(bTotal * 255);
    aTotal2 = Math.round(aTotal2 * 255);

    return { red: rTotal, green: gTotal, blue: bTotal, alpha: aTotal2 };
}

/* Backend24 (3.24+) Specific Functions (Not backwards compatible) */

function initialize_background_styles() {
    register_background_color(get_theme_background_color(), Settings.get_current_user_theme());
    register_background_color(Settings.get_panel_color());

    let tweaked_apps = Object.keys(Settings.app_settings_manager['enable_background_tweaks']);
    let tweaked_windows = Object.keys(Settings.window_settings_manager['enable_background_tweaks']);

    for (let key of tweaked_apps) {
        let prefix = key.split('.').join('-');

        if (Settings.app_settings_manager['maximized_opacity'][key]) {
            register_background_color(Util.tuple_to_native_color(Settings.app_settings_manager['panel_color'][key]), prefix, 'tweaks', Settings.window_settings_manager['maximized_opacity'][key]);
        } else {
            register_background_color(Util.tuple_to_native_color(Settings.app_settings_manager['panel_color'][key]), prefix, 'tweaks');
        }
    }

    for (let key of tweaked_windows) {
        let prefix = key.split('.').join('-');

        if (Settings.window_settings_manager['maximized_opacity'][key]) {
            register_background_color(Util.tuple_to_native_color(Settings.window_settings_manager['panel_color'][key]), prefix, 'tweaks', Settings.window_settings_manager['maximized_opacity'][key]);
        } else {
            register_background_color(Util.tuple_to_native_color(Settings.window_settings_manager['panel_color'][key]), prefix, 'tweaks');
        }
    }
}

function cleanup_background_styles() {
    remove_background_color();
}

function register_background_style(style) {
    if (this.background_styles.indexOf(style) === -1) {
        this.background_styles.push(style);
    }
}

function register_background_color(bg_color, prefix, tweak_name, maximized_opacity, unmaximized_opacity) {
    let suffix = (prefix ? '-' + prefix : '');

    if (prefix === '') {
        prefix = '-default-';
    } else if (prefix) {
        prefix = '-' + prefix + '-';
    } else {
        prefix = '-';
    }

    if (tweak_name) {
        tweak_name = tweak_name + '/';
        prefix = '-tweak' + prefix;
    } else {
        tweak_name = '';
    }

    maximized_opacity = Util.clamp(((maximized_opacity ? maximized_opacity : get_maximized_opacity()) / SCALE_FACTOR), 0, 1).toFixed(2);
    unmaximized_opacity = Util.clamp(((unmaximized_opacity ? unmaximized_opacity : get_unmaximized_opacity()) / SCALE_FACTOR), 0, 1).toFixed(2);

    let maximized_bg_color_css = 'rgba(' + bg_color.red + ', ' + bg_color.green + ', ' + bg_color.blue + ', ' + maximized_opacity + ')';
    let unmaximized_bg_color_css = 'rgba(' + bg_color.red + ', ' + bg_color.green + ', ' + bg_color.blue + ', ' + unmaximized_opacity + ')';

    register_background_style('dpt-panel' + prefix + 'maximized');
    register_background_style('dpt-panel' + prefix + 'unmaximized');

    let file_prefix = 'background/' + tweak_name + 'panel';

    let panel = apply_stylesheet_css('.dpt-panel' + prefix + 'unmaximized { background-color: ' + unmaximized_bg_color_css + '; }\n.dpt-panel' + prefix + 'maximized { background-color: ' + maximized_bg_color_css + '; }', file_prefix + suffix);

    return panel;
}

function set_unmaximized_background_color(prefix) {
    if (prefix) {
        prefix = '-' + prefix + '-';
    } else {
        prefix = '-';
    }

    let style = 'dpt-panel' + prefix + 'unmaximized';

    Panel.actor.add_style_class_name(style);
}

function set_maximized_background_color(prefix) {
    if (prefix) {
        prefix = '-' + prefix + '-';
    } else {
        prefix = '-';
    }

    let style = 'dpt-panel' + prefix + 'maximized';

    Panel.actor.add_style_class_name(style);
}

function remove_unmaximized_background_color(prefix) {
    if (prefix) {
        prefix = '-' + prefix + '-';
    } else {
        prefix = '-';
    }

    Panel.actor.remove_style_class_name('dpt-panel' + prefix + 'unmaximized');
}

function remove_maximized_background_color(prefix) {
    if (prefix) {
        prefix = '-' + prefix + '-';
    } else {
        prefix = '-';
    }

    Panel.actor.remove_style_class_name('dpt-panel' + prefix + 'maximized');
}

function remove_background_color(params) {
    params = Params.parse(params, {
        exclude: null,
        exclude_maximized_variant_only: false,
        exclude_unmaximized_variant_only: false,
        exclude_base: false
    });

    let prefix = null;

    if (params.exclude) {
        prefix = '-' + params.exclude + '-';
    } else if (params.exclude_base) {
        prefix = '-';
    }

    let excluded_maximized_style = (prefix === null ? null : 'dpt-panel' + prefix) + 'maximized';
    let excluded_unmaximized_style = (prefix === null ? null : 'dpt-panel' + prefix) + 'unmaximized';

    for (let style of this.background_styles) {
        let a = params.exclude_maximized_variant_only && style !== excluded_maximized_style;
        let b = params.exclude_unmaximized_variant_only && style !== excluded_unmaximized_style;
        let c = !params.exclude_maximized_variant_only && !params.exclude_unmaximized_variant_only && style !== excluded_maximized_style && style !== excluded_unmaximized_style;

        if (c || a || b) {
            Panel.actor.remove_style_class_name(style);
        }
    }
}

function _updatePanelCSS() {
    let duration_css = Settings.get_transition_speed();

    let stylesheet = apply_stylesheet_css('.dpt-panel-transition-duration { transition-duration: ' + duration_css + 'ms; }', 'transitions/panel-transition-duration');

    Panel.actor.add_style_class_name('dpt-panel-transition-duration');

    register_style('dpt-panel-transition-duration');

    return stylesheet;
}
