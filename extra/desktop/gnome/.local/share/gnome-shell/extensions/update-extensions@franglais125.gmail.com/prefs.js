const GObject = imports.gi.GObject;
const Gtk = imports.gi.Gtk;
const Gio = imports.gi.Gio;
const Lang = imports.lang;
const Me = imports.misc.extensionUtils.getCurrentExtension();
const Utils = Me.imports.utils;

const Gettext = imports.gettext.domain('update-extensions');
const _ = Gettext.gettext;

let settings;

function init() {
    settings = Utils.getSettings(Me);
    Utils.initTranslations("update-extensions");
}

function buildPrefsWidget(){

    // Prepare labels and controls
    let buildable = new Gtk.Builder();
    buildable.add_from_file( Me.dir.get_path() + '/Settings.ui' );
    let box = buildable.get_object('prefs_widget');

    buildable.get_object('extension_version').set_text(Me.metadata.version.toString());

    // Basic settings tab:
    // Update interval
    settings.bind('check-interval',
                  buildable.get_object('interval'),
                  'value',
                  Gio.SettingsBindFlags.DEFAULT);

    // Hours, days or weeks
    buildable.get_object('interval_unit_combo').connect('changed', function(widget) {
        settings.set_enum('interval-unit', widget.get_active());
    });
    buildable.get_object('interval_unit_combo').set_active(settings.get_enum('interval-unit'));

    // System-wide extensions
    settings.bind('system-wide-ext',
                  buildable.get_object('system_wide_ext'),
                  'active',
                  Gio.SettingsBindFlags.DEFAULT);

    // Transient notifications
    settings.bind('transient',
                  buildable.get_object('transient_notifications'),
                  'active',
                  Gio.SettingsBindFlags.DEFAULT);

    box.show_all();

    return box;
};

