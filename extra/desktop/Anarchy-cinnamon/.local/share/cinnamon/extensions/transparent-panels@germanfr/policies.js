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

const Meta = imports.gi.Meta;
const SignalManager = imports.misc.signalManager;

const META_WINDOW_MAXIMIZED = (Meta.MaximizeFlags.VERTICAL | Meta.MaximizeFlags.HORIZONTAL);

function PolicyBase(controller) {
	this._init(controller);
}

PolicyBase.prototype = {
	_init: function (controller) {
		this.controller = controller;
	},

	enable: function () {
	},

	disable: function () {
	},

	is_transparent: function (panel) {
		return true;
	}
};

function MaximizedPolicy(controller) {
	this._init(controller);
}

MaximizedPolicy.prototype = {
	__proto__: PolicyBase.prototype,

	_init: function (controller) {
		PolicyBase.prototype._init.call(this, controller);

		let n_monitors = global.screen.get_n_monitors();
		this.transparent = new Array(n_monitors);
		while(n_monitors--) this.transparent[n_monitors] = true;
	},

	enable: function () {
		this._signals = new SignalManager.SignalManager(null);
		this._signals.connect(global.window_manager, "maximize", this._on_window_appeared, this);
		this._signals.connect(global.window_manager, "map", this._on_window_appeared, this);

		this._signals.connect(global.window_manager, "minimize", this._on_window_disappeared, this);
		this._signals.connect(global.window_manager, "unmaximize", this._on_window_disappeared, this);
		this._signals.connect(global.screen, "window-removed", this.lookup_all_monitors, this);
		this._signals.connect(global.window_manager, "switch-workspace", this.lookup_all_monitors, this);

		this._set_up_startup_signals();
	},

	disable: function () {
		this._signals.disconnectAllSignals();
		this._signals = null;

		if(this._startup_signals) {
			this._startup_signals.disconnectAllSignals();
			this._startup_signals = null;
		}

		this.controller = null;
	},

	is_transparent: function (panel) {
		return this.transparent[panel.monitorIndex];
	},

	// No windows present at startup, but we need to connect to desktops somehow.
	// Listen to a window-created when they don"t exist yet until any
	// window gains focus, when all are supposed to be created (can be improved).
	_set_up_startup_signals: function () {
		let windows = global.display.list_windows(0);

		if(windows.length == 0) { // When the extension is loaded at startup
			this._startup_signals = new SignalManager.SignalManager(null);
			this._startup_signals.connect(global.display, "window-created", this._on_window_added_startup, this);
			this._startup_signals.connect(global.display, "notify::focus-window", this._disconnect_startup_signals, this);
		} else { // When the extension is loaded in the middle of a session
			for(let win of windows)
				this._on_window_added_startup(global.display, win);
		}
		this.controller.on_state_change(-1);
	},

	_disconnect_startup_signals: function () {
		this._startup_signals.disconnectAllSignals();
		this._startup_signals = null;
	},

	// Parse windows status at startup
	_on_window_added_startup: function (display, win) {
		if(win.get_window_type() === Meta.WindowType.DESKTOP) {
			this._signals.connect(win, "focus", this._on_desktop_focused, this);
		} else if(this._is_window_maximized(win)) {
			let monitor = win.get_monitor();
			if(this.transparent[monitor]) {
				this.transparent[monitor] = false;
				this.controller.on_state_change(monitor);
			}
		}
	},

	_is_window_maximized: function (win) {
		return !win.minimized &&
			(win.get_maximized() & META_WINDOW_MAXIMIZED) === META_WINDOW_MAXIMIZED &&
			win.get_window_type() !== Meta.WindowType.DESKTOP;
	},

	_on_window_appeared: function (wm, win) {
		let metawin = win.get_meta_window();
		let monitor = metawin.get_monitor();
		if(this._is_window_maximized(metawin) && this.transparent[monitor]) {
			this.transparent[monitor] = false;
			this.controller.on_state_change(monitor);
		}
	},

	_on_window_disappeared: function (wm, win) {
		if(win.get_meta_window)
			win = win.get_meta_window();
		this.lookup_windows_state(win.get_monitor());
	},

	_on_desktop_focused: function (desktop) {
		if(desktop.get_window_type() !== Meta.WindowType.DESKTOP)
			return;

		let monitor = desktop.get_monitor();
		this.transparent[monitor] = true;
		this.controller.on_state_change(monitor);

		// Listen to focus on other windows since desktop is focused until another
		// window gains focus, to avoid innecesary overhead each time focus changes.
		const focus_lost = (display) => {
			let focused = display.get_focus_window();
			if(desktop === focused || focused.get_monitor() !== monitor)
				return;
			this._signals.disconnect("notify::focus-window", display, focus_lost);
			this.lookup_all_monitors();
		};
		this._signals.connect(global.display, "notify::focus-window", focus_lost);
	},

	_any_maximized_window: function (monitor) {
		let workspace = global.screen.get_active_workspace();
		let windows = workspace.list_windows();

		for(let win of windows) {
			if(this._is_window_maximized(win) && win.get_monitor() == monitor)
				return true;
		}
		return false;
	},

	lookup_windows_state: function (monitor) {
		let maximized = this._any_maximized_window(monitor);
		if(maximized === this.transparent[monitor]) {
			this.transparent[monitor] = !maximized;
			this.controller.on_state_change(monitor);
		}
	},

	lookup_all_monitors: function () {
		let monitors = global.screen.get_n_monitors();
		for(let i = 0; i < monitors; i++)
			this.lookup_windows_state(i);
	}
};
