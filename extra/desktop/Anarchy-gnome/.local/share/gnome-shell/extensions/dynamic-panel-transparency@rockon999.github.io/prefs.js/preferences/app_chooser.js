/* exported AppChooser */

const Lang = imports.lang;

const GObject = imports.gi.GObject;
const Gdk = imports.gi.Gdk;
const Gio = imports.gi.Gio;
const Gtk = imports.gi.Gtk;

const ExtensionUtils = imports.misc.extensionUtils;

const Tweaks = imports.preferences.tweaks;

const gtk30_ = imports.gettext.domain('gtk30').gettext;

/* Translated and modified from gnome-tweak-tool's StartupTweak.py */
// TODO: Transition UI to XML.

const AppChooser = new Lang.Class({
    Name: 'DynamicPanelTransparency_AppChooser',
    Extends: Gtk.Dialog,
    _init: function(main_window, excluded_apps) {
        this.parent({ title: gtk30_("Select Application"), use_header_bar: true });
        this.all = {};
        this.entry = new Gtk.SearchEntry();
        this.entry.set_width_chars(30);
        this.entry.activates_default = true;
        this.searchbar = new Gtk.SearchBar();
        this.searchbar.add(this.entry);
        this.searchbar.hexpand = true;
        let list_box = new Gtk.ListBox();
        list_box.activate_on_single_click = false;
        list_box.set_sort_func(Lang.bind(this, this.sort_apps));
        list_box.set_header_func(Lang.bind(this, this.list_header_func));
        list_box.set_filter_func(Lang.bind(this, this.list_filter_func));
        this.entry.connect('search-changed', Lang.bind(this, this.on_search_entry_changed));
        list_box.connect('row-activated', Lang.bind(this, function(b, r) {
            return this.response(Gtk.ResponseType.OK) ? r.get_mapped() : null;
        }));
        list_box.connect('row-selected', Lang.bind(this, this.on_row_selected));

        let apps = Gio.app_info_get_all();

        for (let x = 0; x < apps.length; x++) {
            let app_info = apps[x];
            if (app_info.should_show() && excluded_apps.indexOf(app_info.get_id()) === -1) {
                let app_widget = this.build_widget(app_info.get_name(), app_info.get_icon());
                if (app_widget) {
                    this.all[app_widget] = app_info;
                    list_box.add(app_widget);
                }
            }
        }

        for (let tweak of Tweaks.get_tweaks()) {
            if (ExtensionUtils.extensions[tweak.uuid]) {
                let app_widget = this.build_widget(tweak.name, null);
                if (app_widget) {
                    this.all[app_widget] = tweak.uuid;
                    list_box.add(app_widget);
                }
            }
        }

        let scrolled_window = new Gtk.ScrolledWindow();
        scrolled_window.hscrollist_boxar_policy = Gtk.PolicyType.NEVER;
        scrolled_window.add(list_box);
        scrolled_window.margin = 5;

        this.add_button(gtk30_("_Close"), Gtk.ResponseType.CANCEL);
        this.add_button(gtk30_("_Select"), Gtk.ResponseType.OK);
        this.set_default_response(Gtk.ResponseType.OK);
        let searchbtn = new Gtk.ToggleButton();
        searchbtn.valign = Gtk.Align.CENTER;
        let image = new Gtk.Image({ icon_name: 'edit-find-symbolic', icon_size: Gtk.IconSize.MENU });
        searchbtn.add(image);
        let context = searchbtn.get_style_context();
        context.add_class('image-button');
        context.remove_class('text-button');
        this.get_header_bar().pack_end(searchbtn);
        this._binding = searchbtn.bind_property('active', this.searchbar, 'search-mode-enabled', GObject.BindingFlags.BIDIRECTIONAL);
        this.get_content_area().pack_start(this.searchbar, false, false, 0);
        this.get_content_area().pack_start(scrolled_window, true, true, 0);
        this.set_modal(true);
        this.set_transient_for(main_window);
        this.set_size_request(400, 300);
        this.listbox = list_box;
        this.connect('key-press-event', Lang.bind(this, this.on_key_press));
    },

    sort_apps: function(a, b, user_data) {
        let aname = null, bname = null;

        if (typeof this.all[a] === 'string') {
            aname = Tweaks.by_uuid(this.all[a]).name;
        } else {
            aname = this.all[a].get_name();
        }

        if (typeof this.all[b] === 'string') {
            bname = Tweaks.by_uuid(this.all[b]).name;
        } else {
            bname = this.all[b].get_name();
        }

        if (aname < bname) {
            return -1;
        } else if (aname > bname) {
            return 1;
        } else {
            return 0;
        }
    },

    build_widget: function(name, icon) {
        let row = new Gtk.ListBoxRow();

        let row_grid = new Gtk.Grid();

        row_grid.set_margin_start(10);
        row_grid.set_margin_end(10);
        row_grid.set_column_spacing(5);

        if (!name) {
            return null;
        }

        let img = null;

        if (icon) {
            img = Gtk.Image.new_from_gicon(icon, Gtk.IconSize.MENU);
        } else {
            img = Gtk.Image.new_from_icon_name('dialog-question', Gtk.IconSize.MENU);
        }

        row_grid.attach(img, 0, 0, 1, 1);

        img.hexpand = false;

        let list_box = new Gtk.Label({
            label: name,
            xalign: 0,
            hexpand: true,
            vexpand: false,
            halign: Gtk.Align.START,
            valign: Gtk.Align.CENTER
        });
        row_grid.attach_next_to(list_box, img, Gtk.PositionType.RIGHT, 1, 1);

        row.add(row_grid);
        row.show_all();

        return row;
    },
    list_header_func: function(row, before, user_data) {
        if (before && !row.get_header()) {
            row.set_header(new Gtk.Separator({ orientation: Gtk.Orientation.HORIZONTAL }));
        }
    },
    list_filter_func: function(row, unused) {
        let txt = this.entry.get_text().toLowerCase();
        let grid = row.get_child();
        for (let sib of grid.get_children()) {
            if (sib.constructor === Gtk.Label) {
                if (sib.get_text().toLowerCase().indexOf(txt) !== -1) {
                    return true;
                }
            }
        }
        return false;
    },
    on_search_entry_changed: function(editable) {
        this.listbox.invalidate_filter();
        let selected = this.listbox.get_selected_row();
        if (selected && selected.get_mapped()) {
            this.set_response_sensitive(Gtk.ResponseType.OK, true);
        } else {
            this.set_response_sensitive(Gtk.ResponseType.OK, false);
        }
    },

    on_row_selected: function(box, row) {
        this.set_response_sensitive(Gtk.ResponseType.OK, row && row.get_mapped());
    },

    on_key_press: function(widget, event) {
        let mods = event.state & Gtk.accelerator_get_default_mod_mask();
        if (event.keyval === this.search_key && mods === this.search_mods) {
            this.searchbar.set_search_mode(!this.searchbar.get_search_mode());
            return true;
        }

        let keyname = Gdk.keyval_name(event.keyval);
        if (keyname === 'Escape') {
            if (this.searchbar.get_search_mode()) {
                this.searchbar.set_search_mode(false);
                return true;
            }
        } else if (!(keyname === 'Up' || keyname === 'Down')) {
            if (!this.entry.has_focus && this.searchbar.get_search_mode()) {
                if (this.entry.im_context_filter_keypress(event)) {
                    this.entry.grab_focus();
                    let l = this.entry.get_text_length();
                    this.entry.select_region(l, l);
                    return true;
                }
                return this.searchbar.handle_event(event);
            }
            return false;
        }
        return false;
    },

    get_selected_app: function() {
        let row = this.listbox.get_selected_row();
        if (row) {
            return this.all[row];
        }
        return null;
    }
});