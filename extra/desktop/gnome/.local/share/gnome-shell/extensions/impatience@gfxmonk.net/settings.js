const Gio = imports.gi.Gio;
const ExtensionUtils = imports.misc.extensionUtils;
const Extension = ExtensionUtils.getCurrentExtension();

const SCHEMA_PATH = 'org.gnome.shell.extensions.net.gfxmonk.impatience';

function get_local_gsettings(schema_path) {
	const GioSSS = Gio.SettingsSchemaSource;

	let schemaDir = Extension.dir.get_child('schemas');

	let schemaSource = GioSSS.get_default();
	if (schemaDir.query_exists(null)) {
		schemaSource = GioSSS.new_from_directory(
			schemaDir.get_path(),
			schemaSource,
			false);
	}

	let schemaObj = schemaSource.lookup(schema_path, true);
	if (!schemaObj) {
		throw new Error(
			'Schema ' + schema_path +
			' could not be found for extension ' +
			Extension.metadata.uuid
		);
	}
	return new Gio.Settings({ settings_schema: schemaObj });
};

function Prefs() {
	var self = this;
	var settings = this.settings = get_local_gsettings(SCHEMA_PATH);
	this.SPEED = {
		key: 'speed-factor',
		get: function() { return settings.get_double(this.key); },
		set: function(v) { settings.set_double(this.key, v); },
		changed: function(cb) { return settings.connect('changed::' + this.key, cb); },
		disconnect: function() { return settings.disconnect.apply(settings, arguments); },
	};
};
