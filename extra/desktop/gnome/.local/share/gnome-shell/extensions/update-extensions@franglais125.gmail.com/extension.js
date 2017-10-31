const St = imports.gi.St;
const Main = imports.ui.main;

const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const Soup = imports.gi.Soup;
const Lang = imports.lang;

const Config = imports.misc.config;
const ExtensionSystem = imports.ui.extensionSystem;
const MessageTray = imports.ui.messageTray;
const Mainloop = imports.mainloop;

const Util = imports.misc.util;
const ExtensionUtils = imports.misc.extensionUtils;
const Me = ExtensionUtils.getCurrentExtension();
const Utils = Me.imports.utils;

const Format = imports.format;
const Gettext = imports.gettext.domain('update-extensions');
const _ = Gettext.gettext;

const REPOSITORY_URL_UPDATE = 'https://extensions.gnome.org/update-info/';

let settings;

let _httpSession;
let _timeoutId = 0;

let metadatas = {};

let LIST = [];
let batches = 0;
let nBatch = 0;

/* Code based on extensionDownloader.js from Jasper St. Pierre */

/* Forked by franglais125 from
 * https://extensions.gnome.org/extension/797/extension-update-notifier/ */

function init() {
    Utils.initTranslations('update-extensions');

    _httpSession = new Soup.SessionAsync({ ssl_use_system_ca_file: true });

    // See: https://bugzilla.gnome.org/show_bug.cgi?id=655189 for context.
    // _httpSession.add_feature(new Soup.ProxyResolverDefault());
    Soup.Session.prototype.add_feature.call(_httpSession, new Soup.ProxyResolverDefault());
}

function openExtensionList() {
    Gio.app_info_launch_default_for_uri('https://extensions.gnome.org/local', global.create_app_launch_context(0, -1));
}

function doNotify() {
    let title = _('Extension Updates Available');
    let message = _('Some of your installed extensions have updated versions available.\n\n');
    message += LIST.join('\n');//

    let notifSource = new MessageTray.SystemNotificationSource();
    notifSource.createIcon = function() {
        return new St.Icon({ icon_name: 'software-update-available-symbolic' });
    };
    // Take care of note leaving unneeded sources
    notifSource.connect('destroy', function() {notifSource = null;});
    Main.messageTray.add(notifSource);

    let notification = null;
    // We do not want to have multiple notifications stacked
    // instead we will update previous
    if (notifSource.notifications.length == 0) {
        notification = new MessageTray.Notification(notifSource, title, message);
        notification.addAction( _('Show updates') , openExtensionList);
    } else {
        notification = notifSource.notifications[0];
        notification.update( title, message, { clear: true });
    }
    notification.setTransient(settings.get_boolean('transient'));
    notifSource.notify(notification);
}

function isLocal(uuid) {
    if (settings.get_boolean('system-wide-ext'))
        return true;
    let extension = ExtensionUtils.extensions[uuid];
    return extension.path.indexOf(GLib.get_home_dir()) != -1;
}

function setMetadata() {
    // Reset
    metadatas = {};

    let countValidExtensions = 0;
    for (let uuid in ExtensionUtils.extensions) {
        if (isLocal(uuid)) {
            if (typeof ExtensionUtils.extensions[uuid].metadata.version == 'number') {
                metadatas[uuid] = ExtensionUtils.extensions[uuid].metadata;
                countValidExtensions++;
            }
            else if (typeof ExtensionUtils.extensions[uuid].metadata.version == 'undefined') {
                // Some extensions, especially global, have no version
                metadatas[uuid] = ExtensionUtils.extensions[uuid].metadata;
                metadatas[uuid].version = 1;
                countValidExtensions++;
            }
        }
    }

    // In groups of 10 or less, not to overload the server
    batches = Math.ceil(countValidExtensions/10.);
}

function getMetadata(i) {
    let batchMetadatas = {};
    let counter = 0;
    for (let uuid in metadatas) {
        if (i*10 <= counter && counter < (i+1)*10)
            batchMetadatas[uuid] = { version: metadatas[uuid].version };
        counter++;
    }
    return batchMetadatas;
}

function checkForUpdates() {
    // Look for all metadatas first
    setMetadata();

    // Reset batch number and list of updates
    nBatch = 0;
    LIST = [];

    for (let i = 0; i < batches; i++) {
        // We get batches of 10
        let batchMetadatas = getMetadata(i);
        let params = { shell_version: Config.PACKAGE_VERSION,
                       installed: JSON.stringify(batchMetadatas) };

        let url = REPOSITORY_URL_UPDATE;
        let message = Soup.form_request_new_from_hash('GET', url, params);
        _httpSession.queue_message(message, function(session, message) {

            let operations = JSON.parse(message.response_body.data);
            for (let uuid in operations) {
                let operation = operations[uuid];
                if (operation == 'blacklist')
                    continue;
                else if (operation == 'upgrade' || operation == 'downgrade')
                    LIST.push(ExtensionUtils.extensions[uuid].metadata.name);
            }

            if (hasFinished() && LIST.length > 0) {
                doNotify();
            }
        });


    }

    scheduleCheck();
}

function hasFinished() {
    nBatch++;
    if (nBatch == batches)
        settings.set_double('last-check-date-double', new Date());

    return nBatch == batches;
}

function scheduleCheck() {
    if (_timeoutId != 0) {
        Mainloop.source_remove(_timeoutId);
        _timeoutId = 0;
    }

    let unit = settings.get_enum('interval-unit');
    let conversion = 0;

    switch (unit) {
    case 0: // Hours
        conversion =          60 * 60;
        break;
    case 1: // Days
        conversion =     24 * 60 * 60;
        break;
    case 2: // Weeks
        conversion = 7 * 24 * 60 * 60;
        break;
    }

    let timeout = conversion * settings.get_int('check-interval');

    // Check how much time passed since the last check
    let last_check = settings.get_double('last-check-date-double');
    let now = new Date();
    let elapsed = (now - last_check)/1000; // Milliseconds to seconds

    // If the difference is low, we should perform a check soon
    timeout -= elapsed;
    if (timeout < 120)
        timeout = 120;

    _timeoutId = Mainloop.timeout_add_seconds(timeout, checkForUpdates);
}

function enable() {
    // Load settings
    settings = Utils.getSettings();

    settings.connect('changed::check-interval', scheduleCheck);
    settings.connect('changed::interval-unit', scheduleCheck);

    scheduleCheck();
}

function disable() {
    if (_timeoutId != 0) {
        Mainloop.source_remove (_timeoutId);
        _timeoutId = 0;
    }

    settings.run_dispose();
    settings = null;
}
