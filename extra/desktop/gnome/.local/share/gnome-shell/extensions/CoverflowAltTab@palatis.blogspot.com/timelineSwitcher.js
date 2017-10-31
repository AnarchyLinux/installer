/* CoverflowAltTab::TimelineSwitcher:
 *
 * Extends CoverflowAltTab::Switcher, switching tabs using a timeline
 */

const Lang = imports.lang;
const Config = imports.misc.config;

const Clutter = imports.gi.Clutter;
const Tweener = imports.ui.tweener;

let ExtensionImports;
if(Config.PACKAGE_NAME == 'cinnamon')
    ExtensionImports = imports.ui.extensionSystem.extensions["CoverflowAltTab@dmo60.de"];
else
    ExtensionImports = imports.misc.extensionUtils.getCurrentExtension().imports;
const BaseSwitcher = ExtensionImports.switcher;

let TRANSITION_TYPE;
const PREVIEW_SCALE = 0.5;

function Switcher() {
    this._init.apply(this, arguments);
}

Switcher.prototype = {
    __proto__: BaseSwitcher.Switcher.prototype,

    _init: function() {
        BaseSwitcher.Switcher.prototype._init.apply(this, arguments);
        if (this._settings.elastic_mode)
        	TRANSITION_TYPE = 'easeOutBack';
        else
        	TRANSITION_TYPE = 'easeOutCubic';
    },

    _createPreviews: function() {
        let monitor = this._activeMonitor;
        let currentWorkspace = global.screen.get_active_workspace();
        this._previews = [];
        for (let i in this._windows) {
            let metaWin = this._windows[i];
            let compositor = this._windows[i].get_compositor_private();
            if (compositor) {
                let texture = compositor.get_texture();
                let [width, height] = texture.get_size();

                let scale = 1.0;
                let previewWidth = monitor.width * PREVIEW_SCALE;
                let previewHeight = monitor.height * PREVIEW_SCALE;
                if (width > previewWidth || height > previewHeight)
                    scale = Math.min(previewWidth / width, previewHeight / height);

                let clone = new Clutter.Clone({
                    opacity: (!metaWin.minimized && metaWin.get_workspace() == currentWorkspace || metaWin.is_on_all_workspaces()) ? 255 : 0,
                    source: texture,
                    reactive: true,
                    anchor_gravity: Clutter.Gravity.WEST,
                    rotation_angle_y: 12,
                    x: ((metaWin.minimized) ? 0 : compositor.x + compositor.width / 2) - monitor.x,
                    y: ((metaWin.minimized) ? 0 : compositor.y + compositor.height / 2) - monitor.y
                });

                clone.target_width = Math.round(width * scale);
                clone.target_height = Math.round(height * scale);
                clone.target_width_side = clone.target_width * 2/3;
                clone.target_height_side = clone.target_height;

                clone.target_x = Math.round(monitor.width * 0.3);
                clone.target_y = Math.round(monitor.height * 0.5) - this._settings.offset;

                this._previews.push(clone);
                this.previewActor.add_actor(clone);
                clone.lower_bottom();
            }
        }
    },

    _previewNext: function() {
        this._currentIndex = (this._currentIndex + 1) % this._windows.length;
        this._updatePreviews(1);
        TRANSITION_TYPE = 'easeOutCubic';
    },

    _previewPrevious: function() {
        this._currentIndex = (this._windows.length + this._currentIndex - 1) % this._windows.length;
        this._updatePreviews(-1);
    },

    _updatePreviews: function(direction) {
        if(this._previews.length == 0)
            return;

        let monitor = this._activeMonitor;
        let animation_time = this._settings.animation_time;
        
        if(this._previews.length == 1) {
            let preview = this._previews[0];
            Tweener.addTween(preview, {
                opacity: 255,
                x: preview.target_x,
                y: preview.target_y,
                width: preview.target_width,
                height: preview.target_height,
                time: animation_time / 2,
                transition: TRANSITION_TYPE
            });
            return;
        }

        // preview windows
        for (let i in this._previews) {
            let preview = this._previews[i];
            i = parseInt(i);
            let distance = (this._currentIndex > i) ? this._previews.length - this._currentIndex + i : i - this._currentIndex;

            if (distance == this._previews.length - 1 && direction > 0) {
                preview.__looping = true;
                Tweener.addTween(preview, {
                    opacity: 0,
                    x: preview.target_x + 200,
                    y: preview.target_y + 100,
                    width: preview.target_width,
                    height: preview.target_height,
                    time: animation_time / 2,
                    transition: TRANSITION_TYPE,
                    onCompleteParams: [preview, distance, animation_time],
                    onComplete: this._onFadeForwardComplete,
                    onCompleteScope: this,
                });
            } else if (distance == 0 && direction < 0) {
                preview.__looping = true;
                Tweener.addTween(preview, {
                    opacity: 0,
                    time: animation_time / 2,
                    transition: TRANSITION_TYPE,
                    onCompleteParams: [preview, distance, animation_time],
                    onComplete: this._onFadeBackwardsComplete,
                    onCompleteScope: this,
                });
            } else {
                let tweenparams = {
                    opacity: 255,
                    x: preview.target_x - Math.sqrt(distance) * 150,
                    y: preview.target_y - Math.sqrt(distance) * 100,
                    width: Math.max(preview.target_width * ((20 - 2 * distance) / 20), 0),
                    height: Math.max(preview.target_height * ((20 - 2 * distance) / 20), 0),
                    time: animation_time,
                    transition: TRANSITION_TYPE,
                };
                if(preview.__looping || preview.__finalTween)
                    preview.__finalTween = tweenparams;
                else
                    Tweener.addTween(preview, tweenparams);
            }
        }
    },

    _onFadeBackwardsComplete: function(preview, distance, animation_time) {
        preview.__looping = false;
        preview.raise_top();

        preview.x = preview.target_x + 200;
        preview.y =  preview.target_y + 100;
        preview.width = preview.target_width;
        preview.height = preview.target_height;

        Tweener.addTween(preview, {
            opacity: 255,
            x: preview.target_x,
            y: preview.target_y,
            width: preview.target_width,
            height: preview.target_height,
            time: animation_time / 2,
            transition: TRANSITION_TYPE,
            onCompleteParams: [preview],
            onComplete: this._onFinishMove,
            onCompleteScope: this,
        });
    },

    _onFadeForwardComplete: function(preview, distance, animation_time) {
        preview.__looping = false;
        preview.lower_bottom();

        preview.x = preview.target_x - Math.sqrt(distance) * 150;
        preview.y = preview.target_y - Math.sqrt(distance) * 100;
        preview.width = Math.max(preview.target_width * ((20 - 2 * distance) / 20), 0);
        preview.height = Math.max(preview.target_height * ((20 - 2 * distance) / 20), 0);

        Tweener.addTween(preview, {
            opacity: 255,
            time: animation_time / 2,
            transition: TRANSITION_TYPE,
            onCompleteParams: [preview],
            onComplete: this._onFinishMove,
            onCompleteScope: this,
        });
    },

    _onFinishMove: function(preview) {
        if(preview.__finalTween) {
            Tweener.addTween(preview, preview.__finalTween);
            preview.__finalTween = null;
        }
    }

};
