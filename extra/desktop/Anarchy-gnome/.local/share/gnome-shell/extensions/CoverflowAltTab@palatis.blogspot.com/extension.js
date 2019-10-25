/* -*- mode: js2; js2-basic-offset: 4; indent-tabs-mode: nil -*- */

/*
 * Cinnamon/Gnome-Shell extension specific routines.
 *
 * Create the correct manager and enable/disable it.
 */

const Config = imports.misc.config;

const PACKAGE_NAME = Config.PACKAGE_NAME;
const PACKAGE_VERSION = Config.PACKAGE_VERSION;

let ExtensionImports;

let HAS_META_KEYBIND_API;
if(PACKAGE_NAME == 'cinnamon') {
    HAS_META_KEYBIND_API = !(PACKAGE_VERSION <= "1.4.0");
    ExtensionImports = imports.ui.extensionSystem.extensions["CoverflowAltTab@dmo60.de"];
}
else {
    HAS_META_KEYBIND_API = true;
    ExtensionImports = imports.misc.extensionUtils.getCurrentExtension().imports;
}

const Manager = ExtensionImports.manager;
const Platform = ExtensionImports.platform;
const Keybinder = ExtensionImports.keybinder;

let manager = null;

function init() {
}

function enable() {
    if (!manager) {
        let platform, keybinder;
        if(PACKAGE_NAME == 'cinnamon') {
            if(PACKAGE_VERSION <= "1.7.2")
                platform = new Platform.PlatformCinnamon();
            else
                platform = new Platform.PlatformCinnamon18();
            keybinder = HAS_META_KEYBIND_API ? new Keybinder.KeybinderNewApi() : new Keybinder.KeybinderOldApi();
        } else {
            if(parseInt(PACKAGE_VERSION.split(".")[1]) >= 21 && PACKAGE_VERSION >= "3.21.0") {
                platform = new Platform.PlatformGnomeShell314();
                keybinder = new Keybinder.Keybinder322Api();
            } else if(parseInt(PACKAGE_VERSION.split(".")[1]) >= 14 && PACKAGE_VERSION >= "3.14.0") {
                platform = new Platform.PlatformGnomeShell314();
                keybinder = new Keybinder.KeybinderNewGSApi();
            } else if(parseInt(PACKAGE_VERSION.split(".")[1]) >= 10 && PACKAGE_VERSION >= "3.10.0") {
                platform = new Platform.PlatformGnomeShell310();
                keybinder = new Keybinder.KeybinderNewGSApi();
            } else if(PACKAGE_VERSION >= "3.8.0") {
                platform = new Platform.PlatformGnomeShell38();
                keybinder = new Keybinder.KeybinderNewGSApi();
            } else {
                platform = new Platform.PlatformGnomeShell();
                keybinder = new Keybinder.KeybinderNewApi();
            }
        }
        manager = new Manager.Manager(platform, keybinder);
    }
    manager.enable();
}

function disable() {
    if (manager) {
        manager.disable();
    }
}
