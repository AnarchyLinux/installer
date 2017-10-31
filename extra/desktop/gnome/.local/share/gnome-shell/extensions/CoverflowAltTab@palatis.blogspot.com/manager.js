/* -*- mode: js2; js2-basic-offset: 4; indent-tabs-mode: nil -*- */

/* CoverflowAltTab::Manager
 *
 * This class is a helper class to start the actual switcher.
 */

const Lang = imports.lang;
const Main = imports.ui.main;

function sortWindowsByUserTime(win1, win2) {
    let t1 = win1.get_user_time();
    let t2 = win2.get_user_time();
    return (t2 > t1) ? 1 : -1 ;
}

function matchSkipTaskbar(win) {
    return !win.is_skip_taskbar();
}

function matchWmClass(win) {
    return win.get_wm_class() == this && !win.is_skip_taskbar();
}

function matchWorkspace(win) {
    return win.get_workspace() == this && !win.is_skip_taskbar();
}

function matchOtherWorkspace(win) {
    return win.get_workspace() != this && !win.is_skip_taskbar();
}

function Manager(platform, keybinder) {
    this._init(platform, keybinder);
}

Manager.prototype = {
    _init: function(platform, keybinder) {
        this.platform = platform;
        this.keybinder = keybinder;
    },

    enable: function() {
        this.platform.enable();
        this.keybinder.enable(Lang.bind(this, this._startWindowSwitcher));
    },

    disable: function() {
        this.platform.disable();
        this.keybinder.disable();
    },

    activateSelectedWindow: function(win) {
        Main.activateWindow(win, global.get_current_time());
    },

    removeSelectedWindow: function(win) {
        win.delete(global.get_current_time());
    },

    _startWindowSwitcher: function(display, screen, window, binding) {
        let windows = [];
        let currentWorkspace = screen.get_active_workspace();

        // Construct a list with all windows
        let windowActors = global.get_window_actors();
        for (let i in windowActors)
            windows.push(windowActors[i].get_meta_window());

        windowActors = null;

        switch(binding.get_name()) {
            case 'switch-panels':
                // Switch between windows of all workspaces
                windows = windows.filter( matchSkipTaskbar );
                // Sort by user time
                windows.sort(sortWindowsByUserTime);
                break;
            case 'switch-group':
                // Switch between windows of same application from all workspaces
                let focused = display.focus_window ? display.focus_window : windows[0];
                windows = windows.filter( matchWmClass, focused.get_wm_class() );
                // Sort by user time
                windows.sort(sortWindowsByUserTime);
                break;
            default:
                let currentOnly = this.platform.getSettings().current_workspace_only;
            	if ( currentOnly == 'all-currentfirst') {
                    // Switch between windows of all workspaces, prefer
            		// those from current workspace
            		let wins1 = windows.filter( matchWorkspace, currentWorkspace );
            		let wins2 = windows.filter( matchOtherWorkspace, currentWorkspace );
                    // Sort by user time
                    wins1.sort(sortWindowsByUserTime);
                    wins2.sort(sortWindowsByUserTime);
                    windows = wins1.concat(wins2);
                    wins1 = [];
                    wins2 = [];
            	} else {
            	    let filter = currentOnly == 'current' ? matchWorkspace : matchSkipTaskbar;
            		// Switch between windows of current workspace
            		windows = windows.filter( filter, currentWorkspace );
                    // Sort by user time
                    windows.sort(sortWindowsByUserTime);
            	}
                break;
        }

        if (windows.length) {
            let mask = binding.get_mask();
            let currentIndex = windows.indexOf(display.focus_window);

            let switcher_class = this.platform.getSettings().switcher_class;
            let switcher = new switcher_class(windows, mask, currentIndex, this);
        }
    }
};
