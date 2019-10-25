const Gtk = imports.gi.Gtk;

let Extension = imports.misc.extensionUtils.getCurrentExtension();
let Settings = Extension.imports.settings;

function init() {
}

function buildPrefsWidget() {
	let config = new Settings.Prefs();
	let frame = new Gtk.Box({
		orientation: Gtk.Orientation.VERTICAL,
		border_width: 10
	});

	(function() {
		let hbox = new Gtk.Box({
			orientation: Gtk.Orientation.HORIZONTAL,
			spacing: 20
		});

		let label = new Gtk.Label({
			label: "Speed scaling\n<small>(1 = normal, 0.5 = twice as fast)</small>",
			use_markup: true,
		});
		let adjustment = new Gtk.Adjustment({
			lower: 0,
			upper: 2,
			step_increment: 0.05
		});
		let scale = new Gtk.HScale({
			digits:2,
			adjustment: adjustment,
			value_pos: Gtk.PositionType.RIGHT
		});

		hbox.add(label);
		hbox.pack_end(scale, true, true, 0);
		frame.add(hbox);

		var pref = config.SPEED;
		scale.set_value(pref.get());
		scale.connect('value-changed', function(sw) {
			var oldval = pref.get();
			var newval = sw.get_value();
			if (newval != pref.get()) {
				pref.set(newval);
			}
		});
	})();

	frame.show_all();
	return frame;
}
