const St = imports.gi.St;
const Gio = imports.gi.Gio;
const Lang = imports.lang;
const DEFAULT_SPEED = 0.75;
const ExtensionUtils = imports.misc.extensionUtils;
const Extension = ExtensionUtils.getCurrentExtension();
const Settings = Extension.imports.settings;

function LOG(m){
	global.log("[impatience] " + m);
	log("[impatience] " + m);
};
function Ext() {
	this._init.apply(this, arguments);
};
var noop = function() {};

Ext.prototype = {};
Ext.prototype._init = function() {
	this.enabled = false;
	this.original_speed = St.get_slow_down_factor();
	this.modified_speed = DEFAULT_SPEED;
	this.unbind = noop;
};

Ext.prototype.enable = function() {
	this.enabled = true;
	var pref = (new Settings.Prefs()).SPEED;
	LOG("enabled");
	var binding = pref.changed(Lang.bind(this, function() {
		this.set_speed(pref.get());
	}));
	this.unbind = function() {
		pref.disconnect(binding);
		this.unbind = noop;
	};
	this.set_speed(pref.get());
};

Ext.prototype.disable = function() {
	this.enabled = false;
	this.unbind();
	St.set_slow_down_factor(this.original_speed);
};

Ext.prototype.set_speed = function(new_speed) {
	if(!this.enabled) {
		LOG("NOT setting new speed, since the extension is disabled.");
		return;
	}
	if(new_speed !== undefined) {
		this.modified_speed = new_speed;
	}
	LOG("setting new speed: " + this.modified_speed);
	St.set_slow_down_factor(this.modified_speed);
};

function init() {
	return new Ext();
};

