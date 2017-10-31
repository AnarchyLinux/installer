/* exported AppRow, CustomRow, AddAppRow */

const Lang = imports.lang;

const Gdk = imports.gi.Gdk;
const Gtk = imports.gi.Gtk;

const C_gtk30_ = imports.gettext.domain('gtk30').pgettext;
const gtk30_ = imports.gettext.domain('gtk30').gettext;

/* Translated and modified from gnome-tweak-tool's StartupTweak.py */
// TODO: Transition UI to XML.

const AppRow = new Lang.Class({
    Name: 'DynamicPanelTransparency_AppRow',
    Extends: Gtk.ListBoxRow,
    _init: function(app_info, on_configure, on_remove) {
        this.parent();

        this.on_configure = on_configure;
        this.on_remove = on_remove;
        this.app_name = app_info.get_name();
        this.app_id = app_info.get_id();

        let grid = new Gtk.Grid({ column_spacing: 10 });

        let icn = app_info.get_icon();
        let img = null;

        if (typeof (icn) !== 'undefined' && icn !== null) {
            img = Gtk.Image.new_from_gicon(icn, Gtk.IconSize.MENU);
            grid.attach(img, 0, 0, 1, 1);
        }

        let lbl = new Gtk.Label({ label: app_info.get_name(), xalign: 0.0 });
        grid.attach_next_to(lbl, img, Gtk.PositionType.RIGHT, 1, 1);
        lbl.hexpand = true;
        lbl.halign = Gtk.Align.START;
        let btn = Gtk.Button.new_with_mnemonic(C_gtk30_('Action name', 'Edit'));
        grid.attach_next_to(btn, lbl, Gtk.PositionType.RIGHT, 1, 1);
        btn.vexpand = false;
        btn.valign = Gtk.Align.CENTER;
        this.btn = btn;
        this.btn.connect('clicked', Lang.bind(this, this.configure));

        let remove_btn = Gtk.Button.new_with_mnemonic(gtk30_("_Remove"));
        grid.attach_next_to(remove_btn, btn, Gtk.PositionType.RIGHT, 1, 1);
        remove_btn.vexpand = false;
        remove_btn.valign = Gtk.Align.CENTER;
        this.remove_btn = remove_btn;
        this.remove_btn.connect('clicked', Lang.bind(this, this.remove));

        this.add(grid);
        this.margin_start = 1;
        this.margin_end = 1;
        this.connect('key-press-event', Lang.bind(this, this.on_key_press_event));
    },
    on_key_press_event: function(row, event) {
        if (event.keyval === Gdk.KEY_Delete || event.keyval === Gdk.KEY_KP_Delete || event.keyval === Gdk.KEY_BackSpace) {
            this.remove_btn.activate();
            return true;
        }
        return false;
    },
    configure: function() {
        this.on_configure.call(this, this.app_name, this.app_id);
    },
    remove: function() {
        this.on_remove.call(this, this.app_id, this);
    }
});

const CustomRow = new Lang.Class({
    Name: 'DynamicPanelTransparency_CustomRow',
    Extends: Gtk.ListBoxRow,
    _init: function(name, wm_class, on_configure, on_remove, wm_class_extra = []) {
        this.parent();

        this.on_configure = on_configure;
        this.on_remove = on_remove;
        this.app_name = wm_class;
        this.app_id = wm_class;
        this.wm_class = wm_class;
        this.wm_class_extra = wm_class_extra;
        this.name = name;

        let grid = new Gtk.Grid({ column_spacing: 10 });

        let lbl = new Gtk.Label({ label: this.name, xalign: 0.0 });
        grid.attach(lbl, 0, 0, 1, 1);
        lbl.hexpand = true;
        lbl.halign = Gtk.Align.START;
        let btn = Gtk.Button.new_with_mnemonic(C_gtk30_('Action name', 'Edit'));
        grid.attach_next_to(btn, lbl, Gtk.PositionType.RIGHT, 1, 1);
        btn.vexpand = false;
        btn.valign = Gtk.Align.CENTER;
        this.btn = btn;
        this.btn.connect('clicked', Lang.bind(this, this.configure));

        let remove_btn = Gtk.Button.new_with_mnemonic(gtk30_("_Remove"));
        grid.attach_next_to(remove_btn, btn, Gtk.PositionType.RIGHT, 1, 1);
        remove_btn.vexpand = false;
        remove_btn.valign = Gtk.Align.CENTER;
        this.remove_btn = remove_btn;
        this.remove_btn.connect('clicked', Lang.bind(this, this.remove));

        this.add(grid);
        this.margin_start = 1;
        this.margin_end = 1;
        this.connect('key-press-event', Lang.bind(this, this.on_key_press_event));
    },
    on_key_press_event: function(row, event) {
        if (event.keyval === Gdk.KEY_Delete || event.keyval === Gdk.KEY_KP_Delete || event.keyval === Gdk.KEY_BackSpace) {
            this.remove_btn.activate();
            return true;
        }
        return false;
    },
    configure: function() {
        this.on_configure.call(this, this.name, this.wm_class, this.wm_class_extra);
    },
    remove: function() {
        this.on_remove.call(this, this.wm_class, this, this.wm_class_extra);
    }
});

const AddAppRow = new Lang.Class({
    Name: 'DynamicPanelTransparency_AddAppRow',
    Extends: Gtk.ListBoxRow,
    _init: function(options) {
        this.parent();
        let img = new Gtk.Image();
        img.set_from_icon_name('list-add-symbolic', Gtk.IconSize.BUTTON);
        this.btn = new Gtk.Button({ label: '', image: img, always_show_image: true });
        this.btn.get_style_context().remove_class('button');
        this.add(this.btn);
    }
});