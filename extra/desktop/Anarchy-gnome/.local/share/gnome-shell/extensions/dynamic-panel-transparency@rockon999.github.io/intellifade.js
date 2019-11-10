/* exported init, cleanup, asyncCheck, syncCheck, forceAsyncCheck, forceSyncCheck, get_current_maximized_window */

const GLib = imports.gi.GLib;
const Mainloop = imports.mainloop;
const Lang = imports.lang;

const Meta = imports.gi.Meta;
const Shell = imports.gi.Shell;

const Main = imports.ui.main;

const Me = imports.misc.extensionUtils.getCurrentExtension();
const Settings = Me.imports.settings;
const Util = Me.imports.util;

const Transitions = Me.imports.transitions;
const Theming = Me.imports.theming;

/* Determines whether to continue the async loop checks. */
let continueCheck = false;
/* Variable for current detected maximized window... */
let maximized_window = null;
/* Run the next change regardless of the whether it is the same as the current status. */
// TODO: Find a nicer way to override optimization code.
let override_optimization = false;
/* Current ID of the async loop (0 if no loop is running) */
let timeoutId = 0;

/* How often the asynchronous loop should run in milliseconds... */
const ASYNC_UPDATE_FREQUENCY = 200; // ms

function init() {
    this._wm_tracker = Shell.WindowTracker.get_default();

    _updateBounds();
}

function cleanup() {
    this._wm_tracker = null;
}

function forceSyncCheck() {
    override_optimization = true;
    syncCheck();
}

function syncCheck() {
    if (Settings.check_overrides() || Settings.check_triggers()) {
        override_optimization = true;
    }

    /* Prevent any asynchronous checks from occuring in the loop. */
    continueCheck = false;
    /* Stop the asynchronous loop... */
    if (timeoutId > 0)
        Mainloop.source_remove(timeoutId);
    /* Remove the old loop ID */
    timeoutId = 0;
    /* Update bounds when a check is done in sync. */
    _updateBounds();
    /* Run a check. */
    _check();
}

function forceAsyncCheck() {
    override_optimization = true;
    asyncCheck();
}

function asyncCheck() {
    if (Settings.check_overrides() || Settings.check_triggers()) {
        override_optimization = true;
    }

    if (timeoutId <= 0) {
        _check();

        timeoutId = Mainloop.timeout_add(ASYNC_UPDATE_FREQUENCY, Lang.bind(this, function() {
            _check();

            if (continueCheck) {
                continueCheck = false;
                return GLib.SOURCE_CONTINUE;
            } else {
                timeoutId = 0;
                return GLib.SOURCE_REMOVE;
            }
        }));
    } else {
        continueCheck = true;
    }

}

function _updateBounds() {
    let panel = Main.panel.actor;

    this.panel_bounds = { x: panel.get_x(), y: panel.get_y(), height: panel.get_height(), width: panel.get_width() };
    this.scale_factor = imports.gi.St.ThemeContext.get_for_stage(global.stage).scale_factor;

    let anchor_y = -Main.layoutManager.panelBox.get_anchor_point()[1];
    let pivot_y = -Main.layoutManager.panelBox.get_pivot_point()[1];

    let buffer = 2;

    // Adjust for bottom panel.
    if (anchor_y > buffer * this.scale_factor) {
        let rect1_y = anchor_y;
        this.panel_bounds.y = rect1_y;
    } else if (pivot_y > buffer * this.scale_factor) {
        let rect1_y = pivot_y;
        this.panel_bounds.y = rect1_y;
    }
}

/* Main extension logic. Modified to fit Gnome Shell 3.26 design patterns. */

// TODO: Cleanup use of variable flags.
function _check() {
    if (Main.overview._shown) {
        return;
    }

    let workspace = global.screen.get_active_workspace();
    let windows = workspace.list_windows();
    windows = global.display.sort_windows_by_stacking(windows);

    let focused_window = global.display.get_focus_window();

    maximized_window = null;

    let add_transparency = true;
    let force_transparency = false;

    /* Handle desktop icons (they're a window too) */
    if (focused_window && focused_window.get_window_type() === Meta.WindowType.DESKTOP) {
        add_transparency = true;
        maximized_window = focused_window;
    } else {
        let buffer = 2;

        // TODO: Always negative? Is pivot negative?
        for (let i = windows.length - 1; i >= 0; i--) {

            let current_window = windows[i];

            if (!current_window.showing_on_its_workspace() || !current_window.is_on_primary_monitor()) {
                continue;
            }

            if (Settings.check_triggers()) {
                /* Check if the current WM_CLASS is a trigger. */
                if (Settings.get_trigger_windows().indexOf(current_window.get_wm_class()) !== -1) {
                    add_transparency = false;
                    maximized_window = current_window;

                    break;
                }

                let app = this._wm_tracker.get_window_app(current_window);

                /* Check if the found app exists and if it is a trigger app. */
                if (app && Settings.get_trigger_apps().indexOf(app.get_id()) !== -1) {
                    add_transparency = false;
                    maximized_window = current_window;

                    break;
                }
            }

            /* Make sure the window is on the correct monitor, isn't minimized, isn't supposed to be excluded, and is actually maximized. */
            if (!Util.is_valid(current_window)) {
                continue;
            }

            if (current_window.maximized_vertically) {
                /* Make sure the top-most window is selected */
                if (maximized_window === null && !force_transparency) {
                    maximized_window = current_window;
                }

                add_transparency = false;

                if (!Settings.check_triggers()) {
                    break;
                }
            }

            let frame = current_window.get_frame_rect();

            if (Main.layoutManager._rightPanelBarrier) {
                let overlap = this.panel_bounds.x < frame.x + frame.width &&
                    this.panel_bounds.x + this.panel_bounds.width > frame.x &&
                    this.panel_bounds.y < frame.y + frame.height &&
                    this.panel_bounds.height + this.panel_bounds.y > frame.y;

                if (overlap) {
                    force_transparency = true;
                    maximized_window = null;

                    if (!Settings.check_triggers()) {
                        break;
                    }
                }
            }
            if (Settings.transition_when_windows_touch_panel()) {
                let touching_panel = frame.y >= (this.panel_bounds.y + this.panel_bounds.height - buffer * this.scale_factor) &&
                    frame.y <= (this.panel_bounds.y + this.panel_bounds.height + buffer * this.scale_factor);

                if (!force_transparency && touching_panel) {
                    add_transparency = false;

                    if (maximized_window === null && !force_transparency) {
                        maximized_window = current_window;
                    }

                    if (!Settings.check_triggers()) {
                        break;
                    }
                }
            }
        }
    }

    if (force_transparency) {
        Transitions.fade_out();
        force_transparency = false;
        /* Only change if the transparency isn't already correct or if override_optimization has been called */
    } else if (Transitions.get_transparency_status().is_blank()) {
        if (add_transparency) {
            Transitions.minimum_fade_in();
        } else {
            Transitions.fade_in();
        }
    } else if (override_optimization || (Transitions.get_transparency_status().is_transparent() !== add_transparency)) {
        override_optimization = false;

        if (add_transparency) {
            Transitions.fade_out();
        } else {
            Transitions.fade_in();
        }
    }

    /* Reset text coloring. */
    if (Settings.get_enable_text_color() && (Settings.get_enable_maximized_text_color() || Settings.get_enable_overview_text_color())) {
        if (!add_transparency && Settings.get_enable_maximized_text_color()) {
            Theming.remove_text_color();
            Theming.set_text_color('maximized');
        } else {
            Theming.remove_text_color('maximized');
            Theming.set_text_color();
        }
    }
}

/**
 * Returns the current visible maximized window as understood by the events' logic.
 * The maximized window is not necessarily the highest window in the z-order.
 *
 * @returns {Object} The current visible maximized window.
 */
function get_current_maximized_window() {
    return maximized_window;
}