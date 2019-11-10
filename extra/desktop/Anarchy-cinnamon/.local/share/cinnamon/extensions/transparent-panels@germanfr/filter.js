/*
* Transparent panels - Cinnamon desktop extension
* Transparentize your panels when there are no any maximized windows
* Copyright (C) 2016  Germán Franco Dorca
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

const Main = imports.ui.main;

function PanelFilter() {
	this._init();
}

PanelFilter.prototype = {
	_init: function () {
		this.panels = [];
		this.filter = [true, true, true, true];

		// for..of doesn't work here because panel[0] is undefined
		Main.getPanels().forEach(panel => this.panels.push(panel));
	},

	for_each_panel: function (callback, monitor) {
		for(let panel of this.panels)
			if(panel.monitorIndex === monitor || monitor < 0)
				callback.call(null, panel, monitor);
	},

	add: function (loc) {
		if(this.filter[loc])
			return;

		Main.getPanels().forEach(panel => {
			if(panel.panelPosition === loc)
				this.panels.push(panel);
		});

		this.filter[loc] = true;
	},

	remove: function (loc) {
		if(!this.filter[loc])
			return;

		for(let i = this.panels.length-1; i >= 0; i--)
			if(this.panels[i].panelPosition === loc)
				this.panels.splice(i, 1);

		this.filter[loc] = false;
	}
};
