config = {
	min_brutes_i: 11,
	max_brutes_i: 11,
	min_failed_i: 11,
	max_failed_i: 11,
	min_blocked_i: 11,
	max_blocked_i: 11,
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
		var name = field.getName();
		var other;
		if (/^min/.test(name)) {
			name = name.replace('min', 'max');
			other = Ext.getCmp(name);
			if (other.getValue() < value) {
				this.minMaxNumberText = 'This field must contain a smaller value than the corresponding max field.';
				return false;
			}
		} else {
			name = name.replace('max', 'min');
			other = Ext.getCmp(name);
			if (other.getValue() > value) {
				this.minMaxNumberText = 'This field must contain a larger value than the corresponding min field.';
				return false;
			}
		}
		if (!validated) {
			validated = true;
			Ext.getCmp(name).validate();
		} else {
			validated = false;
		}
		return true;
	},
	minMaxNumberText: 'The field must contain a positive number, greater than or equal to the corresponding min value or less than or equal to the correspondong max value.',
});

var data2 = [{hour:'08:00', brutes:298, failed:2252, blocked:1050},{hour:'09:00', brutes:213, failed:2194, blocked:1061},{hour:'10:00', brutes:3496, failed:2361, blocked:1134},{hour:'11:00', brutes:3460, failed:2640, blocked:1267},{hour:'12:00', brutes:2946, failed:2289, blocked:1140},{hour:'13:00', brutes:3650, failed:2751, blocked:1324},{hour:'14:00', brutes:3239, failed:2394, blocked:1253},{hour:'15:00', brutes:3200, failed:2360, blocked:1155},{hour:'16:00', brutes:3636, failed:2755, blocked:1324},{hour:'17:00', brutes:4012, failed:352, blocked:1729},{hour:'18:00', brutes:3505, failed:243, blocked:1391},{hour:'19:00', brutes:3301, failed:2567, blocked:1354},{hour:'20:00', brutes:3277, failed:2385, blocked:11252},{hour:'21:00', brutes:3860, failed:3027, blocked:1565},{hour:'22:00', brutes:2945, failed:2554, blocked:1268},{hour:'23:00', brutes:3369, failed:2798, blocked:1320},{hour:'00:00', brutes:3404, failed:2340, blocked:1161},{hour:'01:00', brutes:3312, failed:2533, blocked:1306},{hour:'02:00', brutes:3084, failed:2409, blocked:1221},{hour:'03:00', brutes:3069, failed:2447, blocked:1255},{hour:'04:00', brutes:3629, failed:2719, blocked:1330},{hour:'05:00', brutes:3113, failed:2535, blocked:1293},{hour:'06:00', brutes:3658, failed:2743, blocked:1522},{hour:'07:00', brutes:3133, failed:2309, blocked:1353}];

Ext.onReady(function () {
	Ext.QuickTips.init();
	stores = new Array();

		setTimeout('stores[0].loadData(data2, false);', 5000);
	var charts = new Array();
	for (var i=0;i<4;i++) {
		stores.push(new Ext.data.JsonStore({
			fields: ['hour', 'brutes', 'failed', 'blocked'],
			data: [{hour:'08:00', brutes:2938, failed:2252, blocked:1050},{hour:'09:00', brutes:3213, failed:2194, blocked:1061},{hour:'10:00', brutes:3496, failed:2361, blocked:1134},{hour:'11:00', brutes:3460, failed:2640, blocked:1267},{hour:'12:00', brutes:2946, failed:2289, blocked:1140},{hour:'13:00', brutes:3650, failed:2751, blocked:1324},{hour:'14:00', brutes:3239, failed:2394, blocked:1253},{hour:'15:00', brutes:3200, failed:2360, blocked:1155},{hour:'16:00', brutes:3636, failed:2755, blocked:1324},{hour:'17:00', brutes:4012, failed:3152, blocked:1729},{hour:'18:00', brutes:3505, failed:2643, blocked:1391},{hour:'19:00', brutes:3301, failed:2567, blocked:1354},{hour:'20:00', brutes:3277, failed:2385, blocked:1252},{hour:'21:00', brutes:3860, failed:3027, blocked:1565},{hour:'22:00', brutes:2945, failed:2554, blocked:1268},{hour:'23:00', brutes:3369, failed:2798, blocked:1320},{hour:'00:00', brutes:3404, failed:2340, blocked:1161},{hour:'01:00', brutes:3312, failed:2533, blocked:1306},{hour:'02:00', brutes:3084, failed:2409, blocked:1221},{hour:'03:00', brutes:3069, failed:2447, blocked:1255},{hour:'04:00', brutes:3629, failed:2719, blocked:1330},{hour:'05:00', brutes:3113, failed:2535, blocked:1293},{hour:'06:00', brutes:3658, failed:2743, blocked:1522},{hour:'07:00', brutes:3133, failed:2309, blocked:1353}]
		}));


		charts.push( new Ext.Panel({
			title: 'servername' + i,
			bodyBorder: false,
			height: '220px',
			width: '440px',
			style: {
				float: 'left',
				'margin-top': 20,
				'margin-left': 20,
				'margin-bottom': i <= 1 ? 0 : 20,
				'margin-right': i%2 == 0 ? 0 : 20,
			},
			items: 	new Ext.chart.LineChart({
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
							color:0xff0000
						}
					},{
						type:'line',
						displayName: 'failed attempts',
						yField: 'failed',
						style: {
							color: 0x00ff00
						}
					},{
						type:'line',
						displayName: 'blocked ip addresses',
						yField: 'blocked',
						style: {
							color: 0x0000ff
						}
					}]
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
			formBind:true,
			handler: function() {
					if ( Ext.getCmp('max_brutes_i').getValue() < Ext.getCmp('min_brutes_i').getValue() ||
						Ext.getCmp('max_failed_i').getValue() < Ext.getCmp('min_failed_i').getValue() ||
						Ext.getCmp('max_blocked_i').getValue() < Ext.getCmp('min_blocked_i').getValue()) {
							Ext.Msg.alert('Min values must be less than the corresponding max values');
					}
					else {
						mySettings.hide();
					}
				}
			},{
			text: "Close",
			handler: function() {
					// clear the data
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
		width: 944,
		layout: 'fit',
		renderTo: 'main',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		items: [ {
				title: 'aaa',
				items: charts,
				height: 574,
				tools:[{
						id:'gear',
						handler: function(){
							mySettings.show();
						}
					}],
			},{
				xtype: 'paging',
				store: null,
				pageSize: 25,
				displayInfo: true,
				displayMsg: 'Displaying topics {0} - {1} of {2}',
				emptyMsg: "No topics to display",
				renderTo: mainPanel,
				items:[
					'-', {
						pressed: false,
		 				enableToggle: true,
						text: 'Show all',
						toggleHandler: null//function(btn, pressed){var view = grid.getView();view.showPreview = pressed;view.refresh();}
					}]
			}],
		});
});
