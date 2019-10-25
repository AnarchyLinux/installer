/* -*- mode: js2; js2-basic-offset: 4; indent-tabs-mode: nil -*- */

/* CoverflowAltTab::Platform
 *
 * These are helper classes to handle gnome-shell / cinnamon differences.
 */

const Lang = imports.lang;
const St = imports.gi.St;
const Gio = imports.gi.Gio;
const Config = imports.misc.config;
const Main = imports.ui.main;
const Meta = imports.gi.Meta;
const Tweener = imports.ui.tweener;

let ExtensionImports;
if(Config.PACKAGE_NAME == 'cinnamon')
    ExtensionImports = imports.ui.extensionSystem.extensions["CoverflowAltTab@dmo60.de"];
else
    ExtensionImports = imports.misc.extensionUtils.getCurrentExtension().imports;

const POSITION_TOP = 1;
const POSITION_BOTTOM = 7;
const SHELL_SCHEMA = "org.gnome.shell.extensions.coverflowalttab";
const TRANSITION_TYPE = 'easeOutQuad';

function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

function AbstractPlatform() {
    this._init();
}

AbstractPlatform.prototype = {
    _init: function() {
    },

    enable: function() {
        throw new Error("Abstract method enable not implemented");
    },

    disable: function() {
        throw new Error("Abstract method disable not implemented");
    },

    getWidgetClass: function() {
        throw new Error("Abstract method getWidgetClass not implemented");
    },

    getWindowTracker: function() {
        throw new Error("Abstract method getWindowTracker not implemented");
    },

    getSettings: function() {
        throw new Error("Abstract method getSettings not implemented");
    },

    getDefaultSettings: function() {
        return {
            animation_time: 0.25,
            dim_factor: 0.4,
            title_position: POSITION_BOTTOM,
            icon_style: 'Classic',
            offset: 0,
            hide_panel: true,
            enforce_primary_monitor: true,
            switcher_class: ExtensionImports.switcher.Switcher,
            elastic_mode: false,
            current_workspace_only: '1',
        };
    },

    getPrimaryModifier: function(mask) {
    	return imports.ui.altTab.primaryModifier(mask);
    },

    initBackground: function() {
    	this._background = Meta.BackgroundActor.new_for_screen(global.screen);
		this._background.hide();
        global.overlay_group.add_actor(this._background);
    },

    dimBackground: function() {
    	this._background.show();
        Tweener.addTween(this._background, {
            dim_factor: this._settings.dim_factor,
            time: this._settings.animation_time,
            transition: TRANSITION_TYPE
        });
    },

    undimBackground: function(onCompleteBind) {
    	Tweener.removeTweens(this._background);
        Tweener.addTween(this._background, {
            dim_factor: 1.0,
            time: this._settings.animation_time,
            transition: TRANSITION_TYPE,
            onComplete: onCompleteBind,
        });
    },

    removeBackground: function() {
    	global.overlay_group.remove_actor(this._background);
    }
}

function PlatformCinnamon() {
    this._init.apply(this, arguments);
}

PlatformCinnamon.prototype = {
    __proto__: AbstractPlatform.prototype,

    _init: function() {
        AbstractPlatform.prototype._init.apply(this, arguments);

        this._settings = null;
        this._configMonitor = null;
        this._configConnection = null;

        let ExtensionMeta = imports.ui.extensionSystem.extensions["CoverflowAltTab@dmo60.de"];
        let ExtensionDir = imports.ui.extensionSystem.extensionMeta["CoverflowAltTab@dmo60.de"].path;
        this._configFile = ExtensionDir + '/config.js';
    },

    enable: function() {
        this.disable();

        // watch for file changes
        let file = Gio.file_new_for_path(this._configFile);
        this._configMonitor = file.monitor(Gio.FileMonitorFlags.NONE, null);
        this._configConnection = this._configMonitor.connect('changed', Lang.bind(this, this._onConfigUpdate));
    },

    disable: function() {
        if(this._configMonitor) {
            this._configMonitor.disconnect(this._configConnection);
            this._configMonitor.cancel();
            this._configMonitor = null;
            this._configConnection = null;
        }
    },

    getWidgetClass: function() {
        return St.Group;
    },

    getWindowTracker: function() {
        return imports.gi.Cinnamon.WindowTracker.get_default();
    },

    getSettings: function() {
        if(!this._settings)
            this._settings = this._loadSettings();
        return this._settings;
    },

    _onConfigUpdate: function() {
        this._settings = null;
    },

    _convertConfigToSettings: function(config) {
        return {
            animation_time: Math.max(config.animation_time, 0),
            dim_factor: clamp(config.dim_factor, 0, 1),
            title_position: (config.title_position == 'Top' ? POSITION_TOP : POSITION_BOTTOM),
            icon_style: (config.icon_style == 'Overlay' ? 'Overlay' : 'Classic'),
            offset: config.offset,
            hide_panel: config.hide_panel === true,
            enforce_primary_monitor: config.enforce_primary_monitor === true,
            elastic_mode: config.elastic_mode === true,
            switcher_class: config.switcher_style == 'Timeline' ? ExtensionImports.timelineSwitcher.Switcher: ExtensionImports.coverflowSwitcher.Switcher,
            current_workspace_only: config.current_workspace_only
        };
    },

    _loadSettings: function() {
        try {
            let file = Gio.file_new_for_path(this._configFile);
            if(file.query_exists(null)) {
                let [flag, data] = file.load_contents(null);
                if(flag) {
                    let config = eval('(' + data + ')');
                    return this._convertConfigToSettings(config);
                }
            }
            global.log("Could not load file: " + this._configFile);
        } catch(e) {
            global.log(e);
        }

        return this.getDefaultSettings();
    }
};

function PlatformCinnamon18() {
    this._init.apply(this, arguments);
}

PlatformCinnamon18.prototype = {
    __proto__: AbstractPlatform.prototype,

    _init: function() {
        AbstractPlatform.prototype._init.apply(this, arguments);

        this._settings = this.getDefaultSettings();
        this._settings.updateSwitcherStyle = function() {
            this.switcher_class = this.switcher_style == 'Timeline' ? ExtensionImports.timelineSwitcher.Switcher: ExtensionImports.coverflowSwitcher.Switcher;
        }
        this._settings.updateTitlePosition = function() {
            this.title_position =  (this.titlePosition == 'Top' ? POSITION_TOP : POSITION_BOTTOM);
        };


        let Settings = imports.ui.settings;

        // Init settings
        let extSettings = new Settings.ExtensionSettings(this._settings, "CoverflowAltTab@dmo60.de");
        function noop() {}
        extSettings.bindProperty(Settings.BindingDirection.ONE_WAY, "animation-time", "animation_time", noop);
        extSettings.bindProperty(Settings.BindingDirection.ONE_WAY, "dim-factor", "dim_factor", noop);
        extSettings.bindProperty(Settings.BindingDirection.ONE_WAY, "title-position", "titlePosition", this._settings.updateTitlePosition);
        extSettings.bindProperty(Settings.BindingDirection.ONE_WAY, "icon-style", "icon_style", noop);
        extSettings.bindProperty(Settings.BindingDirection.ONE_WAY, "offset", "offset", noop);
        extSettings.bindProperty(Settings.BindingDirection.ONE_WAY, "hide-panel", "hide_panel", noop);
        extSettings.bindProperty(Settings.BindingDirection.ONE_WAY, "enforce-primary-monitor", "enforce_primary_monitor", noop);
        extSettings.bindProperty(Settings.BindingDirection.ONE_WAY, "elastic-mode", "elastic_mode", noop);
        extSettings.bindProperty(Settings.BindingDirection.ONE_WAY, "switcher-style", "switcher_style", this._settings.updateSwitcherStyle);
        extSettings.bindProperty(Settings.BindingDirection.ONE_WAY, "current-workspace-only", "current_workspace_only", noop);

        this._settings.updateSwitcherStyle();
        this._settings.updateTitlePosition();
    },

    enable: function() {
    },

    disable: function() {
    },

    getWidgetClass: function() {
        return St.Group;
    },

    getWindowTracker: function() {
        return imports.gi.Cinnamon.WindowTracker.get_default();
    },

    getSettings: function() {
        return this._settings;
    },

    getPrimaryModifier: function(mask) {
    	return imports.ui.appSwitcher.appSwitcher.primaryModifier(mask);
    }

};

function PlatformGnomeShell() {
    this._init.apply(this, arguments);
}

PlatformGnomeShell.prototype = {
    __proto__: AbstractPlatform.prototype,

    _init: function() {
        AbstractPlatform.prototype._init.apply(this, arguments);

        this._settings = null;
        this._connections = null;
        this._gioSettings = null;
    },

    enable: function() {
        this.disable();

        if(this._gioSettings == null)
            this._gioSettings = ExtensionImports.lib.getSettings(SHELL_SCHEMA);

        let keys = [
            "animation-time",
            "dim-factor",
            "position",
            "icon-style",
            "offset",
            "hide-panel",
            "enforce-primary-monitor",
            "elastic-mode",
            "current-workspace-only",
        ];

        this._connections = [];
        let bind = Lang.bind(this, this._onSettingsChaned);
        keys.forEach(function(key) { this._connections.push(this._gioSettings.connect('changed::' + key, bind)); }, this);
        this._settings = this._loadSettings();
    },

    disable: function() {
        if(this._connections) {
            this._connections.forEach(function(connection) { this._gioSettings.disconnect(connection); }, this);
            this._connections = null;
        }
        this._settings = null;
    },

    getWidgetClass: function() {
        return St.Widget;
    },

    getWindowTracker: function() {
        return imports.gi.Shell.WindowTracker.get_default();
    },

    getSettings: function() {
        if(!this._settings)
            this._settings = this._loadSettings();
        return this._settings;
    },

    _onSettingsChaned: function() {
        this._settings = null;
    },

    _loadSettings: function() {
        try {
            let settings = this._gioSettings;
            return {
                animation_time: Math.max(settings.get_int("animation-time") / 1000, 0),
                dim_factor: clamp(settings.get_int("dim-factor") / 10, 0, 1),
                title_position: (settings.get_string("position") == 'Top' ? POSITION_TOP : POSITION_BOTTOM),
                icon_style: (settings.get_string("icon-style") == 'Overlay' ? 'Overlay' : 'Classic'),
                offset: settings.get_int("offset"),
                hide_panel: settings.get_boolean("hide-panel"),
                enforce_primary_monitor: settings.get_boolean("enforce-primary-monitor"),
                elastic_mode: settings.get_boolean("elastic-mode"),
                switcher_class: settings.get_string("switcher-style") == 'Timeline' ? ExtensionImports.timelineSwitcher.Switcher: ExtensionImports.coverflowSwitcher.Switcher,
                current_workspace_only: settings.get_string("current-workspace-only")
            };
        } catch(e) {
            global.log(e);
        }

        return this.getDefaultSettings();
    },
};

function PlatformGnomeShell38() {
    this._init.apply(this, arguments);
}

PlatformGnomeShell38.prototype = {
	    __proto__: PlatformGnomeShell.prototype,

	    _init: function() {
	    	PlatformGnomeShell.prototype._init.apply(this, arguments);
	    },

	    getPrimaryModifier: function(mask) {
	    	return imports.ui.switcherPopup.primaryModifier(mask);
	    },

	    initBackground: function() {
	    	let Background = imports.ui.background;

	    	this._backgroundGroup = new Meta.BackgroundGroup();
	        global.overlay_group.add_child(this._backgroundGroup);
	        this._backgroundGroup.hide();
	        for (let i = 0; i < Main.layoutManager.monitors.length; i++) {
	            new Background.BackgroundManager({ container: this._backgroundGroup,
	                                               monitorIndex: i, });
	        }
	    },

	    dimBackground: function() {
	    	let Background = imports.ui.background;

	    	this._backgroundGroup.show();
        	let backgrounds = this._backgroundGroup.get_children();
            for (let i = 0; i < backgrounds.length; i++) {
                let background = backgrounds[i]._delegate;

                Tweener.addTween(background,
                                 { brightness: this.getSettings().dim_factor,
                                   time: this.getSettings().animation_time,
                                   transition: TRANSITION_TYPE
                                 });
            }
	    },

	    undimBackground: function(onCompleteBind) {
	    	let Background = imports.ui.background;

	    	let backgrounds = this._backgroundGroup.get_children();
            for (let i = 0; i < backgrounds.length; i++) {
                let background = backgrounds[i]._delegate;

                Tweener.addTween(background,
                                 { brightness: 1.0,
                                   time: this.getSettings().animation_time,
                                   transition: TRANSITION_TYPE,
                                   onComplete: onCompleteBind,
                                 });
            }
	    },

	    removeBackground: function() {
	    	global.overlay_group.remove_child(this._backgroundGroup);
	    }
};

function PlatformGnomeShell310() {
    this._init.apply(this, arguments);
}

PlatformGnomeShell310.prototype = {
	    __proto__: PlatformGnomeShell.prototype,

	    _init: function() {
	    	PlatformGnomeShell.prototype._init.apply(this, arguments);
	    },

	    getPrimaryModifier: function(mask) {
	    	return imports.ui.switcherPopup.primaryModifier(mask);
	    },

	    initBackground: function() {
	    	let Background = imports.ui.background;

	    	this._backgroundGroup = new Meta.BackgroundGroup();
	        Main.uiGroup.add_child(this._backgroundGroup);
	        this._backgroundGroup.lower_bottom();
	        this._backgroundGroup.hide();
	        for (let i = 0; i < Main.layoutManager.monitors.length; i++) {
	            new Background.BackgroundManager({ container: this._backgroundGroup,
	                                               monitorIndex: i, });
	        }
	    },

	    dimBackground: function() {
	    	let Background = imports.ui.background;

	    	this._backgroundGroup.show();
        	let backgrounds = this._backgroundGroup.get_children();
            for (let i = 0; i < backgrounds.length; i++) {
                let background = backgrounds[i]._delegate;
                Tweener.addTween(background,
                                 { brightness: this.getSettings().dim_factor,
                                   time: this.getSettings().animation_time,
                                   transition: TRANSITION_TYPE
                                 });
            }
	    },

	    undimBackground: function(onCompleteBind) {
	    	let Background = imports.ui.background;

	    	let backgrounds = this._backgroundGroup.get_children();
            for (let i = 0; i < backgrounds.length; i++) {
                let background = backgrounds[i]._delegate;
                Tweener.addTween(background,
                                 { brightness: 1.0,
                                   time: this.getSettings().animation_time,
                                   transition: TRANSITION_TYPE,
                                   onComplete: onCompleteBind,
                                 });
            }
	    },

	    removeBackground: function() {
	    	Main.uiGroup.remove_child(this._backgroundGroup);
	    }
};



function PlatformGnomeShell314() {
    this._init.apply(this, arguments);
}

PlatformGnomeShell314.prototype = {
	    __proto__: PlatformGnomeShell.prototype,

	    _init: function() {
	    	PlatformGnomeShell.prototype._init.apply(this, arguments);
	    },

	    getPrimaryModifier: function(mask) {
	    	return imports.ui.switcherPopup.primaryModifier(mask);
	    },

	    initBackground: function() {
	    	let Background = imports.ui.background;

	    	this._backgroundGroup = new Meta.BackgroundGroup();
        Main.layoutManager.uiGroup.add_child(this._backgroundGroup);
        this._backgroundGroup.lower_bottom();
        this._backgroundGroup.hide();
        for (let i = 0; i < Main.layoutManager.monitors.length; i++) {
            new Background.BackgroundManager({ container: this._backgroundGroup,
                                               monitorIndex: i,
                                               vignette: true });
        }
	    },

	    dimBackground: function() {
	    	this._backgroundGroup.show();
        let backgrounds = this._backgroundGroup.get_children();
        for (let i = 0; i < backgrounds.length; i++) {
            Tweener.addTween(backgrounds[i],
                             { brightness: 0.8,
                               vignette_sharpness: 1 - this.getSettings().dim_factor,
                               time: this.getSettings().animation_time,
                               transition: TRANSITION_TYPE
                             });
        }
	    },

	    undimBackground: function(onCompleteBind) {
        let backgrounds = this._backgroundGroup.get_children();
        for (let i = 0; i < backgrounds.length; i++) {
            Tweener.addTween(backgrounds[i],
                             { brightness: 1.0,
                               vignette_sharpness: 0.0,
                               time: this.getSettings().animation_time,
                               transition: TRANSITION_TYPE,
                               onComplete: onCompleteBind
                             });
        }
	    },

	    removeBackground: function() {
	    	Main.layoutManager.uiGroup.remove_child(this._backgroundGroup);
	    }
};
