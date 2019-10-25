/* exported init, enable, disable */

const Lang = imports.lang;
const Mainloop = imports.mainloop;

const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const St = imports.gi.St;

const ExtensionSystem = imports.ui.extensionSystem;
const Main = imports.ui.main;

const Me = imports.misc.extensionUtils.getCurrentExtension();

const Convenience = Me.imports.convenience;
const Events = Me.imports.events;
const Intellifade = Me.imports.intellifade;
const Settings = Me.imports.settings;
const Util = Me.imports.util;

const Theming = Me.imports.theming;
const Transitions = Me.imports.transitions;

const SETTINGS_DELAY = 3000;

const USER_THEME_SCHEMA = 'org.gnome.shell.extensions.user-theme';

/* Only way to prevent multiple runs apparently. Hacky-ness. */
let modified = false;

/* User theme extension settings... */
let theme_settings = null;

/* Initialize */
function init() { }

function enable() {
    /* Initialize Settings */
    initialize_settings();

    /* Initialize Utilities */
    Transitions.init();
    Theming.init();
    Intellifade.init();

    /* Try to load settings for the user theme plugin. */
    // TODO: Why doesn't this work on some Ubuntu installations?
    try {
        let schemaObj = Convenience.getSchemaObj(USER_THEME_SCHEMA, true);

        if (schemaObj) {
            theme_settings = new Gio.Settings({
                settings_schema: schemaObj
            });
        }
    } catch (error) {
        log('[Dynamic Panel Transparency] Failed to find the user theme extension.');
    }

    if (!theme_settings) {
        idle_enable(false);
    } else {
        /* Is our data current? */
        let theme_name = theme_settings.get_string('name');
        theme_name = theme_name === '' ? 'Adwaita' : theme_name;

        let current = Settings.get_current_user_theme();

        if (current !== theme_name || Settings.force_theme_update()) {
            /* Wait for the theme extension to initialize and enable. */
            idle_enable(true, theme_settings);
        } else {
            /* Start the plugin. We have our data. */
            log('[Dynamic Panel Transparency] Using theme data for: ' + Settings._settings.get_string('current-user-theme'));

            let theme_color = Settings.get_panel_theme_color();
            let opacity = Settings.get_theme_opacity();

            Theming.set_theme_background_color(theme_color);
            Theming.set_theme_opacity(opacity);

            /* Modify the panel. */
            modify_panel();

            /* Start the event loop. */
            Events.init();

            /* Simulate window changes. */
            Intellifade.forceSyncCheck();
        }
    }
}

function idle_enable(update, theme_settings = null) {
    /* Delay the extension so we can retreive the theme background color (why are user themes an extension?). */
    Mainloop.idle_add(Lang.bind(this, function() {
        let extension = imports.misc.extensionUtils.getCurrentExtension();

        if (modified) {
            log('[Dynamic Panel Transparency] Attempted to run modifications multiple times.');
            return false;
        }

        if (!extension || (extension && typeof (extension.extensionState) !== 'undefined' && extension.extensionState === ExtensionSystem.ExtensionState.DISABLED)) {
            log('[Dynamic Panel Transparency] Tried to modify the panel while disabled.');
            return false;
        }

        modified = true;

        let background = null;

        if (update) {
            log('[Dynamic Panel Transparency] Updating user theme data.');

            let theme = Main.panel.actor.get_theme_node();

            let image_background = Theming.get_background_image_color(theme);
            let theme_background = theme.get_background_color();

            background = (image_background !== null ? image_background : theme_background);

            let theme_name = theme_settings.get_string('name');
            theme_name = theme_name === '' ? 'Adwaita' : theme_name;

            /* The Settings convenience object wasn't built to handle setting, so we use the internal object... */
            Settings._settings.set_string('current-user-theme', theme_name);
            Settings._settings.set_value('panel-theme-color', new GLib.Variant('(iii)', [background.red, background.green, background.blue]));
            Settings._settings.set_value('theme-opacity', new GLib.Variant('i', background.alpha));
            Settings._settings.set_value('force-theme-update', new GLib.Variant('b', false));
            log('[Dynamic Panel Transparency] Detected shell theme style: rgba(' + background.red + ', ' + background.green + ', ' + background.blue + ', ' + background.alpha + ')');
        } else {
            let color = Settings.get_panel_theme_color();
            let opacity = Settings.get_theme_opacity();

            background = { red: color.red, blue: color.blue, green: color.green, alpha: opacity };
        }

        log('[Dynamic Panel Transparency] Using theme data for: ' + Settings.get_current_user_theme());

        Theming.set_theme_background_color(Util.clutter_to_native_color(background));
        Theming.set_theme_opacity(background.alpha);

        /* Modify the panel. */
        modify_panel();

        /* Start the event loop. */
        Events.init();

        /* Simulate window changes. */
        Intellifade.forceSyncCheck();

        return false;
    }));
}

function disable() {
    /* Do this first in case any of the upcoming methods fail. */
    unmodify_panel();

    /* Disconnect & Null Signals */
    Events.cleanup();

    /* Cleanup Settings */
    Settings.unbind();
    Settings.cleanup();

    /* Cleanup Transitions */
    Transitions.cleanup();

    /* Cleanup Theming */
    Theming.cleanup();

    /* Cleanup Intellifade */
    Intellifade.cleanup();

    /* Shouldn't be an issue, but let's make sure it isn't. */
    modified = false;

    return false;
}

function modify_panel() {
    /* Initial Coloring */

    let theme_color = Theming.get_theme_background_color();

    /* Update the corners. */

    Theming.set_corner_color({
        red: theme_color.red,
        green: theme_color.green,
        blue: theme_color.blue
    });

    /* Get Rid of the Panel's CSS Background */
    Theming.initialize_background_styles();

    let text_shadow = Theming.register_text_shadow(Settings.get_text_shadow_color(), Settings.get_text_shadow_position());
    let icon_shadow = Theming.register_icon_shadow(Settings.get_icon_shadow_color(), Settings.get_icon_shadow_position());

    /* Add Text Shadowing */
    if (Settings.add_text_shadow()) {
        if (text_shadow !== null) {
            Theming.add_text_shadow();
        } else {
            log('[Dynamic Panel Transparency] Failed to enabled text shadowing.');
        }
    }

    /* Add Icon Shadowing */
    if (Settings.add_icon_shadow()) {
        if (icon_shadow !== null) {
            Theming.add_icon_shadow();
        } else {
            log('[Dynamic Panel Transparency] Failed to enabled icon shadowing.');
        }
    }

    /* Register text color styling. */
    let [text, icon, arrow] = Theming.register_text_color(Settings.get_text_color()); // eslint-disable-line no-unused-vars
    let [maximized_text, maximized_icon, maximized_arrow] = Theming.register_text_color(Settings.get_maximized_text_color(), 'maximized'); // eslint-disable-line no-unused-vars

    if (Settings.get_enable_text_color()) {
        if (text !== null) {
            Theming.set_text_color();
        } else {
            log('[Dynamic Panel Transparency] Failed to enabled text coloring.');
        }
    }
}

function unmodify_panel() {

    /* Remove corner styling */
    Theming.clear_corner_color();

    /* Remove Our Styling */
    Theming.reapply_panel_styling();
    Theming.reapply_panel_background();
    Theming.reapply_panel_background_image();

    /* Remove shadowing */
    if (Theming.has_text_shadow()) {
        Theming.remove_text_shadow();
    }

    if (Theming.has_icon_shadow()) {
        Theming.remove_icon_shadow();
    }

    /* Remove text coloring */
    Theming.remove_text_color();

    /* Remove maximized text coloring */
    Theming.remove_text_color('maximized');
}

// TODO: Merge handler code or hide it behind the backend.
function initialize_settings() {
    /* Setup settings... */
    Settings.init();

    /* Register settings... */
    Settings.add({
        key: 'hide-corners',
        name: 'hide_corners',
        type: 'b',
        handler: Lang.bind(this, function() {
            Transitions.update_corner_alpha();
        })
    });
    Settings.add({
        key: 'transition-speed',
        name: 'transition_speed',
        type: 'i',
        handler: Lang.bind(this,
            /* Update the backend24 transition CSS. */
            function() {
                Main.panel.actor.remove_style_class_name('dpt-panel-transition-duration');

                let theme = St.ThemeContext.get_for_stage(global.stage).get_theme();

                for (let i = Theming.stylesheets.length - 1; i >= 0; i--) {
                    let stylesheet = Theming.stylesheets[i];
                    if (stylesheet.contains('transitions') && stylesheet.endsWith('panel-transition-duration.dpt.css')) {
                        theme.unload_stylesheet(Util.get_file(stylesheet));
                        Util.remove_file(stylesheet);
                        Theming.stylesheets.splice(i, 1);
                    }
                }

                const id = this.panel_transition_update_id = Mainloop.timeout_add(SETTINGS_DELAY, Lang.bind(this, function() { // eslint-disable-line no-magic-numbers
                    if (id !== this.panel_transition_update_id) {
                        return false;
                    }

                    /* Get Rid of the Panel's CSS Background */
                    // TODO: Figure out why it takes applying wierd "fake" style classes to get the real ones working...
                    Theming._updatePanelCSS();

                    Intellifade.forceSyncCheck();

                    return false;
                }));
            })
    });
    Settings.add({
        key: 'unmaximized-opacity',
        name: 'unmaximized_opacity',
        type: 'i',
        getter: 'get_unmaximized_opacity',
        handler: Lang.bind(this, function() {
            const super_id = this.opacity_update_id = Mainloop.timeout_add(SETTINGS_DELAY, Lang.bind(this, function() {
                if (super_id !== this.opacity_update_id) {
                    return false;
                }

                Theming.reapply_panel_background();

                let theme = St.ThemeContext.get_for_stage(global.stage).get_theme();

                for (let i = Theming.stylesheets.length - 1; i >= 0; i--) {
                    let stylesheet = Theming.stylesheets[i];
                    if (stylesheet.contains('background') && stylesheet.contains('panel-')) {
                        theme.unload_stylesheet(Util.get_file(stylesheet));
                        Util.remove_file(stylesheet);
                        Theming.stylesheets.splice(i, 1);
                    }
                }

                Theming.initialize_background_styles();

                const id = this.panel_color_update_id = Mainloop.timeout_add(SETTINGS_DELAY, Lang.bind(this, function() { // eslint-disable-line no-magic-numbers
                    if (id !== this.panel_color_update_id) {
                        return false;
                    }

                    /* Get Rid of the Panel's CSS Background */
                    // TODO: Figure out why it takes applying wierd "fake" style classes to get the real ones working...

                    Theming.set_maximized_background_color((Math.random() * 100).toFixed(0));
                    Theming.remove_background_color();
                    Theming.set_unmaximized_background_color((Math.random() * 100).toFixed(0));
                    Theming.remove_background_color();

                    Intellifade.forceSyncCheck();

                    return false;
                }));

                return false;
            }));
        })
    });
    Settings.add({
        key: 'maximized-opacity',
        name: 'maximized_opacity',
        type: 'i',
        getter: 'get_maximized_opacity',
        handler: Lang.bind(this, function() {
            const super_id = this.opacity_update_id = Mainloop.timeout_add(SETTINGS_DELAY, Lang.bind(this, function() {
                if (super_id !== this.opacity_update_id) {
                    return false;
                }

                Theming.reapply_panel_background();

                let theme = St.ThemeContext.get_for_stage(global.stage).get_theme();

                for (let i = Theming.stylesheets.length - 1; i >= 0; i--) {
                    let stylesheet = Theming.stylesheets[i];
                    if (stylesheet.contains('background') && stylesheet.contains('panel-')) {
                        theme.unload_stylesheet(Util.get_file(stylesheet));
                        Util.remove_file(stylesheet);
                        Theming.stylesheets.splice(i, 1);
                    }
                }

                Theming.initialize_background_styles();

                const id = this.panel_color_update_id = Mainloop.timeout_add(SETTINGS_DELAY, Lang.bind(this, function() { // eslint-disable-line no-magic-numbers
                    if (id !== this.panel_color_update_id) {
                        return false;
                    }

                    /* Get Rid of the Panel's CSS Background */
                    // TODO: Figure out why it takes applying wierd "fake" style classes to get the real ones working...

                    Theming.set_maximized_background_color((Math.random() * 100).toFixed(0));
                    Theming.remove_background_color();
                    Theming.set_unmaximized_background_color((Math.random() * 100).toFixed(0));
                    Theming.remove_background_color();

                    Intellifade.forceSyncCheck();

                    return false;
                }));

                return false;
            }));
        })
    });
    Settings.add({
        key: 'panel-color',
        name: 'panel_color',
        type: 'ai',
        parser: Util.tuple_to_native_color,
        handler: Lang.bind(this,
            /* Handler for 3.24+ */
            function() {
                Theming.remove_background_color();

                let theme = St.ThemeContext.get_for_stage(global.stage).get_theme();

                for (let i = Theming.stylesheets.length - 1; i >= 0; i--) {
                    let stylesheet = Theming.stylesheets[i];
                    if (stylesheet.contains('background') && stylesheet.contains('panel.dpt.css')) {
                        theme.unload_stylesheet(Util.get_file(stylesheet));
                        Util.remove_file(stylesheet);
                        Theming.stylesheets.splice(i, 1);
                    }
                }
                Theming.register_background_color(Settings.get_panel_color());
                const id = this.panel_color_update_id = Mainloop.timeout_add(SETTINGS_DELAY, Lang.bind(this, function() { // eslint-disable-line no-magic-numbers
                    if (id !== this.panel_color_update_id) {
                        return false;
                    }

                    /* Get Rid of the Panel's CSS Background */
                    // TODO: Figure out why it takes applying wierd "fake" style classes to get the real ones working...

                    Theming.set_maximized_background_color((Math.random() * 100).toFixed(0));
                    Theming.remove_background_color();
                    Theming.set_unmaximized_background_color((Math.random() * 100).toFixed(0));
                    Theming.remove_background_color();

                    Intellifade.forceSyncCheck();

                    return false;
                }));
                /* Legacy Handler */
            })
    });
    Settings.add({
        key: 'panel-theme-color',
        name: 'panel_theme_color',
        type: '(iii)',
        parser: Util.tuple_to_native_color
    });
    Settings.add({
        key: 'theme-opacity',
        name: 'theme_opacity',
        type: 'i',
    });
    Settings.add({
        key: 'force-theme-update',
        name: 'force_theme_update',
        type: 'b',
        getter: 'force_theme_update'
    });
    Settings.add({
        key: 'current-user-theme',
        name: 'current_user_theme',
        type: 's',
    });
    Settings.add({
        key: 'trigger-apps',
        name: 'trigger_apps',
        type: 'as'
    });
    Settings.add({
        key: 'trigger-windows',
        name: 'trigger_windows',
        type: 'as'
    });
    Settings.add({
        key: 'text-shadow',
        name: 'text_shadow',
        type: 'b',
        getter: 'add_text_shadow',
        handler: Lang.bind(this, function() {
            if (Settings.add_text_shadow()) {
                Theming.add_text_shadow();
            } else {
                Theming.remove_text_shadow();
            }
        })
    });
    Settings.add({
        key: 'icon-shadow',
        name: 'icon_shadow',
        type: 'b',
        getter: 'add_icon_shadow',
        handler: Lang.bind(this, function() {
            if (Settings.add_icon_shadow()) {
                Theming.add_icon_shadow();
            } else {
                Theming.remove_icon_shadow();
            }
        })
    });
    Settings.add({
        key: 'text-shadow-position',
        name: 'text_shadow_position',
        type: '(iii)',
        handler: Lang.bind(this, function() {
            Theming.remove_text_shadow();

            let theme = St.ThemeContext.get_for_stage(global.stage).get_theme();

            for (let i = Theming.stylesheets.length - 1; i >= 0; i--) {
                let stylesheet = Theming.stylesheets[i];
                if (stylesheet.contains('shadow') && stylesheet.contains('text')) {
                    theme.unload_stylesheet(Util.get_file(stylesheet));
                    Util.remove_file(stylesheet);
                    Theming.stylesheets.splice(i, 1);
                }
            }
            let text_shadow = Theming.register_text_shadow(Settings.get_text_shadow_color(), Settings.get_text_shadow_position());
            const id = this.text_shadow_update_id = Mainloop.timeout_add(SETTINGS_DELAY, Lang.bind(this, function() { // eslint-disable-line no-magic-numbers
                if (id !== this.text_shadow_update_id) {
                    return false;
                }

                /* Add Text Shadowing */
                if (Settings.add_text_shadow()) {
                    if (text_shadow !== null) {
                        Theming.add_text_shadow();
                    } else {
                        log('[Dynamic Panel Transparency] Failed to enabled text shadowing.');
                    }
                }

                Intellifade.forceSyncCheck();

                return false;
            }));
        })
    });
    Settings.add({
        key: 'icon-shadow-position',
        name: 'icon_shadow_position',
        type: '(iii)',
        handler: Lang.bind(this, function() {
            Theming.remove_icon_shadow();

            let theme = St.ThemeContext.get_for_stage(global.stage).get_theme();

            for (let i = Theming.stylesheets.length - 1; i >= 0; i--) {
                let stylesheet = Theming.stylesheets[i];
                if (stylesheet.contains('shadow') && stylesheet.contains('icon')) {
                    theme.unload_stylesheet(Util.get_file(stylesheet));
                    Util.remove_file(stylesheet);
                    Theming.stylesheets.splice(i, 1);
                }
            }
            let icon_shadow = Theming.register_icon_shadow(Settings.get_icon_shadow_color(), Settings.get_icon_shadow_position());
            const id = this.icon_shadow_update_id = Mainloop.timeout_add(SETTINGS_DELAY, Lang.bind(this, function() { // eslint-disable-line no-magic-numbers
                if (id !== this.icon_shadow_update_id) {
                    return false;
                }

                /* Add Icon Shadowing */
                if (Settings.add_icon_shadow()) {
                    if (icon_shadow !== null) {
                        Theming.add_icon_shadow();
                    } else {
                        log('[Dynamic Panel Transparency] Failed to enabled icon shadowing.');
                    }
                }

                Intellifade.forceSyncCheck();

                return false;
            }));
        })
    });
    Settings.add({
        key: 'icon-shadow-color',
        name: 'icon_shadow_color',
        type: '(iiid)',
        parser: Util.tuple_to_native_color,
        handler: Lang.bind(this, function() {
            Theming.remove_icon_shadow();

            let theme = St.ThemeContext.get_for_stage(global.stage).get_theme();

            for (let i = Theming.stylesheets.length - 1; i >= 0; i--) {
                let stylesheet = Theming.stylesheets[i];
                if (stylesheet.contains('shadow') && stylesheet.contains('icon')) {
                    theme.unload_stylesheet(Util.get_file(stylesheet));
                    Util.remove_file(stylesheet);
                    Theming.stylesheets.splice(i, 1);
                }
            }
            let icon_shadow = Theming.register_icon_shadow(Settings.get_icon_shadow_color(), Settings.get_icon_shadow_position());
            const id = this.icon_shadow_update_id = Mainloop.timeout_add(SETTINGS_DELAY, Lang.bind(this, function() { // eslint-disable-line no-magic-numbers
                if (id !== this.icon_shadow_update_id) {
                    return false;
                }

                /* Add Icon Shadowing */
                if (Settings.add_icon_shadow()) {
                    if (icon_shadow !== null) {
                        Theming.add_icon_shadow();
                    } else {
                        log('[Dynamic Panel Transparency] Failed to enabled icon shadowing.');
                    }
                }

                Intellifade.forceSyncCheck();

                return false;
            }));
        })
    });
    Settings.add({
        key: 'text-shadow-color',
        name: 'text_shadow_color',
        type: '(iiid)',
        parser: Util.tuple_to_native_color,
        handler: Lang.bind(this, function() {
            Theming.remove_text_shadow();

            let theme = St.ThemeContext.get_for_stage(global.stage).get_theme();

            for (let i = Theming.stylesheets.length - 1; i >= 0; i--) {
                let stylesheet = Theming.stylesheets[i];
                if (stylesheet.contains('shadow') && stylesheet.contains('text')) {
                    theme.unload_stylesheet(Util.get_file(stylesheet));
                    Util.remove_file(stylesheet);
                    Theming.stylesheets.splice(i, 1);
                }
            }
            let text_shadow = Theming.register_text_shadow(Settings.get_text_shadow_color(), Settings.get_text_shadow_position());
            const id = this.text_shadow_update_id = Mainloop.timeout_add(SETTINGS_DELAY, Lang.bind(this, function() { // eslint-disable-line no-magic-numbers
                if (id !== this.text_shadow_update_id) {
                    return false;
                }

                /* Add Text Shadowing */
                if (Settings.add_text_shadow()) {
                    if (text_shadow !== null) {
                        Theming.add_text_shadow();
                    } else {
                        log('[Dynamic Panel Transparency] Failed to enabled text shadowing.');
                    }
                }

                Intellifade.forceSyncCheck();

                return false;
            }));
        })
    });
    Settings.add({
        key: 'text-color',
        name: 'text_color',
        type: '(iii)',
        parser: Util.tuple_to_native_color
    });
    Settings.add({
        key: 'maximized-text-color',
        name: 'maximized_text_color',
        type: '(iii)',
        parser: Util.tuple_to_native_color
    });
    Settings.add({
        key: 'enable-maximized-text-color',
        name: 'enable_maximized_text_color',
        type: 'b',
        handler: Lang.bind(this, function() {
            Intellifade.forceSyncCheck();
        })
    });
    Settings.add({
        key: 'remove-panel-styling',
        name: 'remove_panel_styling',
        getter: 'remove_panel_styling',
        type: 'b'
    });
    Settings.add({
        key: 'enable-overview-text-color',
        name: 'enable_overview_text_color',
        type: 'b'
    });
    Settings.add({
        key: 'enable-text-color',
        name: 'enable_text_color',
        type: 'b',
        handler: Lang.bind(this, function() {
            if (Settings.get_enable_text_color()) {
                Intellifade.forceSyncCheck();
            } else {
                Theming.remove_text_color();
                Theming.remove_text_color('maximized');
            }
        })
    });
    Settings.add({
        key: 'enable-opacity',
        name: 'enable_custom_opacity',
        getter: 'enable_custom_opacity',
        type: 'b'
    });
    Settings.add({
        key: 'enable-background-color',
        name: 'enable_custom_background_color',
        getter: 'enable_custom_background_color',
        type: 'b'
    });
    Settings.add({
        key: 'transition-with-overview',
        name: 'transition_with_overview',
        getter: 'transition_with_overview',
        type: 'b'
    });
    Settings.add({
        key: 'transition-windows-touch',
        name: 'transition_windows_touch',
        getter: 'transition_when_windows_touch_panel',
        type: 'b'
    });

    /* App-Specific Settings */

    Settings.add_app_setting({
        key: 'enable-background-tweaks',
        name: 'enable_background_tweaks',
        type: 'b'
    });
    Settings.add_app_override({
        key: 'maximized-opacity',
        name: 'maximized_opacity',
        type: 'i'
    });
    Settings.add_app_override({
        key: 'panel-color',
        name: 'panel_color',
        type: '(iii)',
        parser: Util.tuple_to_native_color
    });

    /* After we've given Settings the necessary information... let's bind it. */
    Settings.bind();
}