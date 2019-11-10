/*
* Transparent panels - Cinnamon desktop extension
* Transparentize your panels when there are no any maximized windows
* Copyright (C) 2016  Germán Franco Dorca
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

const UUID = "transparent-panels@germanfr";

const Gettext = imports.gettext;
const GLib = imports.gi.GLib;
const Main = imports.ui.main;
const MessageTray = imports.ui.messageTray;
const Panel = imports.ui.panel;
const Settings = imports.ui.settings;
const St = imports.gi.St;
const Util = imports.misc.util;

let Filter, Policies;
if (typeof require !== 'undefined') {
	Filter = require('./filter');
	Policies = require('./policies');
} else {
	const Self = imports.ui.extensionSystem.extensions[UUID];
	Filter = Self.filter;
	Policies = Self.policies;
}

const ANIMATIONS_DURATION = 200;
const INTERNAL_PREFIX = "__internal";


function _(str) {
	let customTranslation = Gettext.dgettext(UUID, str);
	if(customTranslation !== str) {
		return customTranslation;
	}
	return Gettext.gettext(str);
}

function MyExtension(meta) {
	this._init(meta);
}

MyExtension.prototype = {
	_init: function (meta) {
		this.meta = meta;
		this._signals = null;
		this._panel_status = new Array(Main.panelManager.panelCount);
		for(let i = 0; i < this._panel_status.length; i++)
			this._panel_status[i] = false;

		this._filter = new Filter.PanelFilter();
		this.policy = new Policies.MaximizedPolicy(this);

		this.settings = new Settings.ExtensionSettings(this, meta.uuid);
		this.settings.bind("transparency-type", "transparency_type", this.on_settings_changed);
		this.settings.bind("theme-defined", "theme_defined", this.on_settings_changed);
		this.settings.bind("opacify", "opacify", this.on_settings_changed);

		this.settings.bind("panel-top", "enable_position_top", this.on_settings_changed);
		this.settings.bind("panel-right", "enable_position_right", this.on_settings_changed);
		this.settings.bind("panel-bottom", "enable_position_bottom", this.on_settings_changed);
		this.settings.bind("panel-left", "enable_position_left", this.on_settings_changed);

		this._classname = this.theme_defined ? this.transparency_type : this.transparency_type + INTERNAL_PREFIX;

		Gettext.bindtextdomain(meta.uuid, GLib.get_home_dir() + "/.local/share/locale");
	},

	enable: function () {
		this._update_filter();
		this.policy.enable();

		if(this.settings.getValue("first-launch")) {
			this.settings.setValue("first-launch", false);
			this._show_startup_notification();
		}
	},

	disable: function () {
		this.policy.disable();
		this.settings.finalize();
		this.settings = null;

		Main.getPanels().forEach(panel => this.make_transparent(panel, false));
	},

	on_state_change: function (monitor) {
		this._filter.for_each_panel(panel => {
			let transparentize = this.policy.is_transparent(panel);
			this.make_transparent(panel, transparentize);
		}, monitor);
	},

	make_transparent: function (panel, transparent) {
		if(transparent === this._panel_status[panel.panelId-1])
			return;
		if(transparent) {
			if(this.opacify)
				this._set_background_opacity(panel, 0);
			panel.actor.add_style_class_name(this._classname);
		} else {
			if(this.opacify)
				this._set_background_opacity(panel, 255);
			panel.actor.remove_style_class_name(this._classname);
		}
		this._panel_status[panel.panelId-1] = transparent;
	},

	_set_background_opacity: function (panel, alpha) {
		let actor = panel.actor;
		let color = actor.get_background_color();
		color.alpha = alpha;
		actor.save_easing_state();
		actor.set_easing_duration(ANIMATIONS_DURATION);
		actor.set_background_color(color);
		actor.restore_easing_state();
	},

	_update_filter: function () {
		if(this.enable_position_top) this._filter.add(Panel.PanelLoc.top);
		else this._filter.remove(Panel.PanelLoc.top);

		if(this.enable_position_right) this._filter.add(Panel.PanelLoc.right);
		else this._filter.remove(Panel.PanelLoc.right);

		if(this.enable_position_bottom) this._filter.add(Panel.PanelLoc.bottom);
		else this._filter.remove(Panel.PanelLoc.bottom);

		if(this.enable_position_left) this._filter.add(Panel.PanelLoc.left);
		else this._filter.remove(Panel.PanelLoc.left);
	},

	on_settings_changed: function () {
		// Remove old classes
		Main.getPanels().forEach(panel => this.make_transparent(panel, false));

		this._classname = this.transparency_type;
		if(!this.theme_defined)
			this._classname += INTERNAL_PREFIX;

		this._update_filter();

		this.on_state_change(-1);
	},

	// This will be called only once, the first time the extension is loaded.
	// It's not worth it to create a separate class, so we build everything here.
	_show_startup_notification: function () {
		let source = new MessageTray.Source(this.meta.name);
		let params = {
			icon: new St.Icon({
					icon_name: "transparent-panels",
					icon_type: St.IconType.FULLCOLOR,
					icon_size: source.ICON_SIZE })
		};

		let notification = new MessageTray.Notification(source,
			_("%s enabled").format(_(this.meta.name)),
			_("Open the extension settings and customize your panels"),
			params);

		notification.addButton("open-settings", _("Open settings"));
		notification.connect("action-invoked", () => this.launch_settngs());

		Main.messageTray.add(source);
		source.notify(notification);
	},

	launch_settngs: function () {
		Util.spawnCommandLine("xlet-settings extension " + this.meta.uuid);
	}
};


let extension = null;

function enable() {
	try {
		extension.enable();
	} catch (err) {
		extension.disable();
		throw err;
	}
}

function disable() {
	try {
		extension.disable();
	} catch(err) {
		global.logError(err);
	} finally {
		extension = null;
	}
}

function init(metadata) {
	extension = new MyExtension(metadata);
}
