/* CoverflowAltTab::Switcher:
 *
 * The implementation of the switcher UI. Handles keyboard events.
 */

const Lang = imports.lang;

const Clutter = imports.gi.Clutter;
const St = imports.gi.St;
const Meta = imports.gi.Meta;
const Mainloop = imports.mainloop;
const Main = imports.ui.main;
const Tweener = imports.ui.tweener;
const Pango = imports.gi.Pango;

const INITIAL_DELAY_TIMEOUT = 150;
const CHECK_DESTROYED_TIMEOUT = 100;
let TRANSITION_TYPE = 'easeOutCubic';
const ICON_SIZE = 64;
const ICON_SIZE_BIG = 128;
const ICON_TITLE_SPACING = 10;


function Switcher() {
    this._init.apply(this, arguments);
}

Switcher.prototype = {
    _init: function(windows, mask, currentIndex, manager) {
        this._manager = manager;
        this._settings = manager.platform.getSettings();
        this._windows = windows;
        this._windowTitle = null;
        this._icon = null;
        this._modifierMask = null;
        this._currentIndex = currentIndex;
        this._haveModal = false;
        this._tracker = manager.platform.getWindowTracker();
        this._windowManager = global.window_manager;
        this._lastTime = 0;
        this._checkDestroyedTimeoutId = 0;

        this._dcid = this._windowManager.connect('destroy', Lang.bind(this, this._windowDestroyed));
        this._mcid = this._windowManager.connect('map', Lang.bind(this, this._activateSelected));
        
		manager.platform.initBackground();
		
        // create a container for all our widgets
        let widgetClass = manager.platform.getWidgetClass();
        this.actor = new widgetClass({ visible: true, reactive: true, });
        this.actor.hide();
        this.previewActor = new widgetClass({ visible: true, reactive: true});
        this.actor.add_actor(this.previewActor);
        
        Main.uiGroup.add_actor(this.actor);

        if (!Main.pushModal(this.actor)) {
            this._activateSelected();
            return;
        }

        this._haveModal = true;

        this.actor.connect('key-press-event', Lang.bind(this, this._keyPressEvent));
        this.actor.connect('key-release-event', Lang.bind(this, this._keyReleaseEvent));
        this.actor.connect('scroll-event', Lang.bind(this, this._scrollEvent));
        
        this._modifierMask = manager.platform.getPrimaryModifier(mask);
        
        let [x, y, mods] = global.get_pointer();
		if (!(mods & this._modifierMask)){
			// There's a race condition; if the user released Alt before
			// we got the grab, then we won't be notified. (See
			// https://bugzilla.gnome.org/show_bug.cgi?id=596695 for
			// details) So we check now. (Have to do this after updating
			// selection.)
			this._activateSelected();
			return;
		}

        this._initialDelayTimeoutId = Mainloop.timeout_add(INITIAL_DELAY_TIMEOUT, Lang.bind(this, this.show));
    },

    show: function() {
        this._enableMonitorFix();
        
        let monitor = this._updateActiveMonitor();
        this.actor.set_position(monitor.x, monitor.y);
        this.actor.set_size(monitor.width, monitor.height);

        // create previews
        this._createPreviews();

        // hide windows and show Coverflow actors
        global.window_group.hide();
        this.actor.show();

        let panels = this.getPanels();
        panels.forEach(function(panel) {
            try {
                panel.actor.set_reactive(false);
                if (this._settings.hide_panel) {
                    Tweener.addTween(panel.actor, {
                        opacity: 0,
                        time: this._settings.animation_time,
                        transition: TRANSITION_TYPE
                    });
                }
            } catch (e) {
                //ignore fake panels
            }
        }, this);

        // hide gnome-shell legacy tray
        try {
            Main.legacyTray.actor.hide();
        } catch (e) {
            //ignore missing legacy tray
        }

        this._manager.platform.dimBackground();
        
        this._initialDelayTimeoutId = 0;

        this._next();
    },

    _createPreviews: function() {
        throw new Error("Abstract method _createPreviews not implemented");
    },

    _updatePreviews: function() {
        throw new Error("Abstract method _updatePreviews not implemented");
    },

    _previewNext: function() {
        throw new Error("Abstract method _previewNext not implemented");
    },

    _previewPrevious: function() {
        throw new Error("Abstract method _previewPrevious not implemented");
    },

    _checkSwitchTime: function() {
        let t = new Date().getTime();
        if(t - this._lastTime < 150)
            return false;
        this._lastTime = t;
        return true;
    },

    _next: function() {
        if(this._windows.length <= 1) {
            this._currentIndex = 0;
            this._updatePreviews(0);
        } else {
            this.actor.set_reactive(false);
            this._previewNext();
            this.actor.set_reactive(true);
        }
        this._setCurrentWindowTitle(this._windows[this._currentIndex]);
    },

    _previous: function() {
        if(this._windows.length <= 1) {
            this._currentIndex = 0;
            this._updatePreviews(0);
        } else {
            this.actor.set_reactive(false);
            this._previewPrevious();
            this.actor.set_reactive(true);
        }
        this._setCurrentWindowTitle(this._windows[this._currentIndex]);
    },

    _updateActiveMonitor: function() {
        this._activeMonitor = null;
        if(!this._settings.enforce_primary_monitor) {
            try {
                let x, y, mask;
                [x, y, mask] = global.get_pointer();
                this._activeMonitor = Main.layoutManager._chrome._findMonitorForRect(x, y, 0, 0);
            } catch(e) {
            }
        }
        if(!this._activeMonitor)
            this._activeMonitor = Main.layoutManager.primaryMonitor;

        return this._activeMonitor;
    },
    
    _setCurrentWindowTitle: function(window) {
        let animation_time = this._settings.animation_time;

        let monitor = this._activeMonitor;

        let app_icon_size;
        let label_offset;
        if (this._settings.icon_style == "Classic") {
            app_icon_size = ICON_SIZE;
            label_offset = ICON_SIZE + ICON_TITLE_SPACING;
        } else {
            app_icon_size = ICON_SIZE_BIG;
            label_offset = 0;
        }

        // window title label
        if (this._windowTitle) {
            Tweener.addTween(this._windowTitle, {
                opacity: 0,
                time: animation_time,
                transition: TRANSITION_TYPE,
                onComplete: Lang.bind(this.actor, this.actor.remove_actor, this._windowTitle),
            });
        }

        this._windowTitle = new St.Label({
            style_class: 'switcher-list',
            text: this._windows[this._currentIndex].get_title(),
            opacity: 0
        });

        // ellipsize if title is too long
        this._windowTitle.set_style("max-width:" + (monitor.width - 200) + "px;font-size: 14px;font-weight: bold; padding: 14px;");
        this._windowTitle.clutter_text.ellipsize = Pango.EllipsizeMode.END;

        this.actor.add_actor(this._windowTitle);
        Tweener.addTween(this._windowTitle, {
            opacity: 255,
            time: animation_time,
            transition: TRANSITION_TYPE,
        });
        
        let cx = Math.round((monitor.width + label_offset) / 2);
        let cy = Math.round(monitor.height * this._settings.title_position / 8 - this._settings.offset);
        
        this._windowTitle.x = cx - Math.round(this._windowTitle.get_width()/2);
        this._windowTitle.y = cy - Math.round(this._windowTitle.get_height()/2);

        // window icon
        if (this._applicationIconBox) {
            Tweener.addTween(this._applicationIconBox, {
                opacity: 0,
                time: animation_time,
                transition: TRANSITION_TYPE,
                onComplete: Lang.bind(this.actor, this.actor.remove_actor, this._applicationIconBox),
            });
        }

        let app = this._tracker.get_window_app(this._windows[this._currentIndex]);
        this._icon = app ? app.create_icon_texture(app_icon_size) : null;

        if (!this._icon) {
            this._icon = new St.Icon({
                icon_name: 'applications-other',
                icon_type: St.IconType.FULLCOLOR,
                icon_size: app_icon_size
            });
        }

        if (this._settings.icon_style == "Classic") {
            this._applicationIconBox = new St.Bin({
                style_class: 'window-iconbox',
                opacity: 0,
                x: Math.round(this._windowTitle.x - app_icon_size - ICON_TITLE_SPACING),
                y: Math.round(cy - app_icon_size/2)
            });
        } else {
            this._applicationIconBox = new St.Bin({
                style_class: 'window-iconbox',
                width: app_icon_size * 1.15,
                height: app_icon_size * 1.15,
                opacity: 0,
                x: (monitor.width - app_icon_size) / 2,
                y: (monitor.height - app_icon_size) / 2,
            });
        }

        this._applicationIconBox.add_actor(this._icon);
        this.actor.add_actor(this._applicationIconBox);
        Tweener.addTween(this._applicationIconBox, {
            opacity: 255,
            time: animation_time,
            transition: TRANSITION_TYPE,
        });
    },

    _keyPressEvent: function(actor, event) {
        switch(event.get_key_symbol()) {
            case Clutter.Escape:
                // Esc -> close CoverFlow
                this.destroy();
                return true;

            case Clutter.q:
            case Clutter.Q:
            case Clutter.F4:
                // Q -> Close window
                this._manager.removeSelectedWindow(this._windows[this._currentIndex]);
                this._checkDestroyedTimeoutId = Mainloop.timeout_add(CHECK_DESTROYED_TIMEOUT,
                        Lang.bind(this, this._checkDestroyed, this._windows[this._currentIndex]));
                return true;

            case Clutter.Right:
            case Clutter.Down:
                // Right/Down -> navigate to next preview
                if(this._checkSwitchTime())
                    this._next();
                return true;

            case Clutter.Left:
            case Clutter.Up:
                // Left/Up -> navigate to previous preview
                if(this._checkSwitchTime())
                    this._previous();
                return true;

            case Clutter.d:
            case Clutter.D:
                // D -> Show desktop
                this._showDesktop();
                return true;
        }
        // default alt-tab
        let event_state = event.get_state();
        let action = global.display.get_keybinding_action(event.get_key_code(), event_state);
        switch(action) {
            case Meta.KeyBindingAction.SWITCH_APPLICATIONS:
            case Meta.KeyBindingAction.SWITCH_GROUP:
            case Meta.KeyBindingAction.SWITCH_WINDOWS:
            case Meta.KeyBindingAction.SWITCH_PANELS:
                if(this._checkSwitchTime()) {
                    // shift -> backwards
                    if(event_state & Clutter.ModifierType.SHIFT_MASK)
                        this._previous();
                    else
                        this._next();
                }
                return true;
            case Meta.KeyBindingAction.SWITCH_APPLICATIONS_BACKWARD:
            case Meta.KeyBindingAction.SWITCH_GROUP_BACKWARD:
            case Meta.KeyBindingAction.SWITCH_WINDOWS_BACKWARD:
            case Meta.KeyBindingAction.SWITCH_PANELS_BACKWARD:
                if(this._checkSwitchTime())
                    this._previous();
                return true;
        }

        return true;
    },

    _keyReleaseEvent: function(actor, event) {
        let [x, y, mods] = global.get_pointer();
        let state = mods & this._modifierMask;

        if (state == 0) {
            if (this._initialDelayTimeoutId != 0)
                this._currentIndex = (this._currentIndex + 1) % this._windows.length;
            this._activateSelected();
        }

        return true;
    },

    // allow navigating by mouse-wheel scrolling
    _scrollEvent: function(actor, event) {
    	if(!this._checkSwitchTime())
    		return true;
        
        switch (event.get_scroll_direction()) {
        	case Clutter.ScrollDirection.SMOOTH:
        		let [dx, dy] = event.get_scroll_delta();
        		if (Math.abs(dx) > Math.abs(dy)) {
        			if (dx > 0)
        				this._next();
        			else
        				this._previous();
        		} else {
        			if (dy > 0)
        				this._next();
        			else
        				this._previous();
        		}
                return true;
                
        	case Clutter.ScrollDirection.LEFT:
        	case Clutter.ScrollDirection.UP:
                this._previous();
                return true;
                
        	case Clutter.ScrollDirection.RIGHT:
        	case Clutter.ScrollDirection.DOWN:
                this._next();
                return true;
        }
        
        return true;
    },

    _windowDestroyed: function(wm, actor) {
		this._removeDestroyedWindow(actor.meta_window);
    },

    _checkDestroyed: function(window) {
        this._checkDestroyedTimeoutId = 0;
        this._removeDestroyedWindow(window);
    },

    _removeDestroyedWindow: function(window) {
        for (let i in this._windows) {
            if (window == this._windows[i]) {
                if (this._windows.length == 1)
                    this.destroy();
                else {
                    this._windows.splice(i, 1);
                    this._previews[i].destroy();
                    this._previews.splice(i, 1);
                    this._currentIndex = (i < this._currentIndex) ? this._currentIndex - 1 :
                    this._currentIndex % this._windows.length;
                    this._updatePreviews(0);
                    this._setCurrentWindowTitle(this._windows[this._currentIndex]);
                }

                return;
            }
        }
    },

    _activateSelected: function() {
        this._manager.activateSelectedWindow(this._windows[this._currentIndex]);
        this.destroy();
    },

    _showDesktop: function() {
        for (let i in this._windows) {
            if (!this._windows[i].minimized)
                this._windows[i].minimize();
        }
        this.destroy();
    },

    _onHideBackgroundCompleted: function() {
    	this._manager.platform.removeBackground();
    	Main.uiGroup.remove_actor(this.actor);
    	
        // show all window actors
        global.window_group.show();
    },

    _onDestroy: function() {
    	if (this._settings.elastic_mode)
    		TRANSITION_TYPE = 'easeOutBack';
    	else
    		TRANSITION_TYPE = 'easeOutCubic';
    	
        let monitor = this._activeMonitor;

        if (this._initialDelayTimeoutId == 0) {
            // preview windows
            let currentWorkspace = global.screen.get_active_workspace();
            for (let i in this._previews) {
                let preview = this._previews[i];
                let metaWin = this._windows[i];
                let compositor = this._windows[i].get_compositor_private();

                if (i != this._currentIndex)
                    preview.lower_bottom();
                let rotation_vertex_x = 0.0;
                if (preview.get_anchor_point_gravity() == Clutter.Gravity.EAST) {
                    rotation_vertex_x = preview.width / 2;
                } else if (preview.get_anchor_point_gravity() == Clutter.Gravity.WEST) {
                    rotation_vertex_x = -preview.width / 2;
                }
                preview.move_anchor_point_from_gravity(compositor.get_anchor_point_gravity());
                preview.rotation_center_y = new Clutter.Vertex({ x: rotation_vertex_x, y: 0.0, z: 0.0 });

                Tweener.addTween(preview, {
                    opacity: (!metaWin.minimized && metaWin.get_workspace() == currentWorkspace
                        || metaWin.is_on_all_workspaces()) ? 255 : 0,
                    x: ((metaWin.minimized) ? 0 : compositor.x) - monitor.x,
                    y: ((metaWin.minimized) ? 0 : compositor.y) - monitor.y,
                    width: (metaWin.minimized) ? 0 : compositor.width,
                    height: (metaWin.minimized) ? 0 : compositor.height,
                    rotation_angle_y: 0.0,
                    time: this._settings.animation_time,
                    transition: TRANSITION_TYPE,
                });
            }

            // window title and icon
            this._windowTitle.hide();
            this._applicationIconBox.hide();

            // panels
            let panels = this.getPanels();
            panels.forEach(function(panel) {
                try {
                    panel.actor.set_reactive(true);
                    if (this._settings.hide_panel) {
                        Tweener.removeTweens(panel.actor);
                        Tweener.addTween(panel.actor, {
                            opacity: 255,
                            time: this._settings.animation_time,
                            transition: TRANSITION_TYPE}
                        );
                    }
                } catch (e) {
                    //ignore fake panels
                }
            }, this);
            // show gnome-shell legacy tray
            try {
                Main.legacyTray.actor.show();
            } catch (e) {
                //ignore missing legacy tray
            }

            this._manager.platform.undimBackground(Lang.bind(this, this._onHideBackgroundCompleted));
            this._disableMonitorFix();
        }

        if (this._haveModal) {
            Main.popModal(this.actor);
            this._haveModal = false;
        }

        if (this._initialDelayTimeoutId != 0)
            Mainloop.source_remove(this._initialDelayTimeoutId);
        if (this._checkDestroyedTimeoutId != 0)
            Mainloop.source_remove(this._checkDestroyedTimeoutId);

        this._windowManager.disconnect(this._dcid);
        this._windowManager.disconnect(this._mcid);
        this._windows = null;
        this._windowTitle = null;
        this._icon = null;
        this._applicationIconBox = null;
        this._previews = null;
        this._initialDelayTimeoutId = null;
        this._checkDestroyedTimeoutId = null;
    },

    getPanels: function() {
        let panels = [Main.panel];
        if(Main.panel2)
            panels.push(Main.panel2);
        // gnome-shell dash
        if(Main.overview._dash)
            panels.push(Main.overview._dash);
        return panels;
    },

    destroy: function() {
        this._onDestroy();
    },
    
    _enableMonitorFix: function() {
        if(global.screen.get_n_monitors() < 2)
            return;
        
        this._updateActiveMonitor();
        this._monitorFix = true;
        this._oldWidth = global.stage.width;
        this._oldHeight = global.stage.height;
        
        let width = 2 * (this._activeMonitor.x + this._activeMonitor.width/2);
        let height = 2 * (this._activeMonitor.y + this._activeMonitor.height/2);
        
        global.stage.set_size(width, height);
    },
    
    _disableMonitorFix: function() {
        if(this._monitorFix) {
            global.stage.set_size(this._oldWidth, this._oldHeight);
            this._monitorFix = false;
        }
    }
};
