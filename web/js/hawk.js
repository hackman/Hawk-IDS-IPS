config = {
	min_brutes_i: 0,
	max_brutes_i: 2000000000,
	min_failed_i: 0,
	max_failed_i: 2000000000,
	min_blocked_i: 0,
	max_blocked_i: 2000000000,
	chartLineSize: 1,
	chartDotSize: 5,
}

var validated = false;

Ext.apply(Ext.form.VTypes, {
	minMaxNumber: function(value, field) {
		if (value == '' || value == null) {
			this.minMaxNumberText = 'This field must not be left blank.';
			return false;
		}
		value = Number(value);
		if ( value < 0) {
			this.minMaxNumberText = 'This field must contain a positive integer.';
			return false;
		}
		var other;
		if (/^min/.test(field.getName())) {
			other = Ext.getCmp(field.getName().replace('min', 'max'));
			if (other.getValue() < value) {
				this.minMaxNumberText = 'This field must contain a smaller value than the corresponding max field.';
				return false;
			}
		} else {
			other = Ext.getCmp(field.getName().replace('max', 'min'));
			if (other.getValue() > value) {
				this.minMaxNumberText = 'This field must contain a larger value than the corresponding min field.';
				return false;
			}
		}
		if (!validated) {
			validated = true;
			other.validate();
		} else {
			validated = false;
		}
		return true;
	},
	minMaxNumberText: 'The field must contain a positive number, greater than or equal to the corresponding min value or less than or equal to the correspondong max value.',
});

Ext.onReady(function () {

	Ext.QuickTips.init();

	var stores = new Array();
	var charts = new Array();

	bigStore = new Ext.data.JsonStore({
		url: '../cgi-bin/master.pl',
		baseParams: {
			txt: 1,
		//	debug: 1,
			min_brutes: config['min_brutes_i'],
			max_brutes: config['max_brutes_i'],
			min_failed: config['min_failed_i'],
			max_failed: config['max_failed_i'],
			min_blocked: config['min_blocked_i'],
			max_blocked: config['max_blocked_i'],
		},
		root: 'servers',
		totalProperty: 'total',
		propertyId: 'num',
		fields: [
			{name: 'chartData', mapping: 'data'},
			{name: 'serverName', mapping: 'name'},
		],
		listeners: {
			load: function() {
				var i;
				console.log("Count: ", bigStore.getCount());
				for (i=0; i < bigStore.getCount(); i++) {
					charts[i].show();
					stores[i].loadData(bigStore.getAt(i).data.chartData);
					charts[i].setTitle('<a href="http://' + bigStore.getAt(i).data.serverName +
						'/~sentry/cgi-bin/hawk-web.pl">' + bigStore.getAt(i).data.serverName + '</a>');
				}
				for (; i < 4; i++) {
					charts[i].setTitle('');
					charts[i].hide();
				}
			}
		}
	});

	for (var i=0;i<4;i++) {

		stores.push(new Ext.data.JsonStore({
			fields: ['hour', 'brutes', 'failed', 'blocked'],
		}));

		charts.push( new Ext.Panel({
			title: 'servername' + i,
			bodyBorder: false,
			style: {
				float: 'left',
				'margin-top': 20,
				'margin-left': 20,
				'margin-bottom': i <= 1 ? 0 : 20,
				'margin-right': i%2 == 0 ? 0 : 20,
			},
			items: 	new Ext.chart.LineChart({
				plugins: [new Ext.ux.plugin.VisibilityMode()],
				store: stores[i],
				url:'ext-3.1.1/resources/charts.swf',
				xField: 'hour',
				height: '220px',
				width: '438px',
				series: [{
						type: 'line',
						displayName: 'bruteforce attempts',
						yField: 'brutes',
						style: {
							color:0xff0000,
							size: config.chartDotSize,
							lineSize: config.chartLineSize,
						}
					},{
						type:'line',
						displayName: 'failed attempts',
						yField: 'failed',
						style: {
							color: 0x00ff00,
							size: config.chartDotSize,
							lineSize: config.chartLineSize,
						}
					},{
						type:'line',
						displayName: 'blocked ip addresses',
						yField: 'blocked',
						style: {
							color: 0x0000ff,
							size: config.chartDotSize,
							lineSize: config.chartLineSize,
						}
					}],
			})
		}));
	}

	var settings_form = new Ext.FormPanel({
		id: 'hawk_settings_form',
		frame: true,
		width: 210,
		autoHeight:true,
		monitorValid: true,
		items: [
			new Ext.form.NumberField({
				width: 40,
				id: 'min_brutes_i',
				labelStyle: 'width:150px',
				fieldLabel: 'Min bruteforce attempts',
				allowBlank: false,
				value: config['min_brutes_i'],//min_bruteforce,
				vtype:'minMaxNumber',
			}),
			new Ext.form.NumberField({
				width: 40,
				id: 'max_brutes_i',
				labelStyle: 'width:150px',
				fieldLabel: 'Max bruteforce attempts',
				allowBlank: false,
				value: config['max_brutes_i'],//max_bruteforce,
				vtype:'minMaxNumber',
			}),
			new Ext.form.NumberField({
				width: 40,
				id:'min_failed_i',
				labelStyle: 'width:150px',
				fieldLabel:'Min failed attempts',
				allowBlank: false,
				value: config['min_failed_i'],//min_failed,
				vtype:'minMaxNumber',
			}),
			new Ext.form.NumberField({
				width: 40,
				id:'max_failed_i',
				labelStyle: 'width:150px',
				fieldLabel:'Max failed attempts',
				allowBlank: false,
				value: config['max_failed_i'],//max_failed,
				vtype:'minMaxNumber',
			}),
			new Ext.form.NumberField({
				width: 40,
				id:'min_blocked_i',
				labelStyle: 'width:150px',
				fieldLabel:'Min blocked IP addresses',
				allowBlank:false,
				value: config['min_blocked_i'],//min_blocked,
				vtype:'minMaxNumber',
			}),
			new Ext.form.NumberField({
				width: 40,
				id:'max_blocked_i',
				labelStyle: 'width:150px',
				fieldLabel:'Max blocked IP addresses',
				allowBlank:false,
				value: config['max_blocked_i'],//max_blocked,
				vtype:'minMaxNumber',
			}),
			],
		buttons: [{
			text: "Save",
			formBind: true,
			handler: function() {
						bigStore.baseParams.max_brutes = Number(Ext.getCmp('max_brutes_i').getValue());
						bigStore.baseParams.min_brutes = Number(Ext.getCmp('min_brutes_i').getValue());
						bigStore.baseParams.max_failed = Number(Ext.getCmp('max_failed_i').getValue());
						bigStore.baseParams.min_failed = Number(Ext.getCmp('min_failed_i').getValue());
						bigStore.baseParams.max_blocked = Number(Ext.getCmp('max_blocked_i').getValue());
						bigStore.baseParams.min_blocked = Number(Ext.getCmp('min_blocked_i').getValue());
						mySettings.hide();
				}
			},{
			text: "Close",
			handler: function() {
					config.max_brutes = bigStore.baseParams.max_brutes;
					config.min_brutes = bigStore.baseParams.min_brutes;
					config.max_failed = bigStore.baseParams.max_failed;
					config.min_failed = bigStore.baseParams.min_failed;
					config.max_blocked = bigStore.baseParams.max_blocked;
					config.min_blocked = bigStore.baseParams.min_blocked;
					mySettings.hide();
				}
			}]
	});

	var mySettings = new Ext.Window({
		id: 'settings',
		xtype: 'form',
		title:"Hawk Settings",
		shadow: true,
		closeAction:'hide',
		resizable: false,
		items: [ settings_form ]
	});

	var mainPanel = new Ext.Panel({
		id:'main-panel',
		title: 'aaa',
		width: 944,
		height: 610,
		renderTo: 'main',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		tools:[{
				id:'gear',
				handler: function(){
					mySettings.show();
				}
			}],
		items: charts,
		bbar:{
				xtype: 'paging',
				id: 'pager',
				store: bigStore,
				pageSize: 4,
				displayInfo: true,
				displayMsg: 'Displaying info for servers {0} - {1} of {2}',
				emptyMsg: "No topics to display",
				renderTo: mainPanel,
				items:[
					'-', {
						pressed: false,
		 				enableToggle: true,
						text: 'Show all',
						toggleHandler: null//function(btn, pressed){var view = grid.getView();view.showPreview = pressed;view.refresh();}
					}, '-', '->', '-', '<label for="ipaddr">Search: </label>',
					new Ext.form.TwinTriggerField({
						id: 'ipaddr',
						name: 'ipaddr',
						emptyText: 'Filter by server name',
						trigger1Class: 'x-form-search-trigger',
						trigger2Class: 'x-form-clear-trigger',
						onTrigger1Click: function(){
							var ipaddr = Ext.getCmp('ipaddr').getValue();
	//						ShowResults(ipaddr);
							for (var i=1;i<=3;i++) {
								charts[i].hide();
							}
						},
						onTrigger2Click: function(){
							var ipaddr = Ext.getCmp('ipaddr').setValue('');
							for (var i=1;i<=3;i++) {
								charts[i].show();
							}
						}
					}),
				],
			},
		});
	bigStore.load({params: {start:0, limit: 4} });
});
