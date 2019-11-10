/* exported get_tweaks, by_uuid, by_name, by_wm_class */

const get_tweaks = function() {
    return [
        {
            'uuid': 'drop-down-terminal@gs-extensions.zzrough.org',
            'name': 'Drop Down Terminal',
            'wm_class': ['DropDownTerminalWindow', 'drop-down-terminal'],
            'trigger': true
        }
    ];
};

const by_uuid = function(uuid) {
    for (let tweak of get_tweaks()) {
        if (uuid === tweak.uuid) {
            return tweak;
        }
    }
    return null;
};

const by_name = function(name) {
    for (let tweak of get_tweaks()) {
        if (name === tweak.name) {
            return tweak;
        }
    }
    return null;
};

const by_wm_class = function(wm_class) {
    for (let tweak of get_tweaks()) {
        if (tweak.wm_class.indexOf(wm_class) !== -1) {
            return tweak;
        }
    }
    return null;
};