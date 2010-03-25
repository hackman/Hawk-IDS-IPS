function ShowResults(ipaddr) {
	alert(ipaddr);
	var failed_data = [
		['2010-03-11 05:29:54', '125.65.7.3'],
		['2010-03-12 02:24:21','24.42.33.11'],
		['2010-03-13 08:21:09','24.99.104.193'],
		['2010-03-14 12:38:03','58.181.108.157'],
		['2010-03-15 10:58:23','67.235.226.74'],
		['2010-03-16 03:28:21','70.26.185.43'],
		['2010-03-17 04:46:01','71.118.16.242'],
		['2010-03-18 01:18:05','72.55.137.101'],
		['2010-03-19 02:49:20','74.55.182.98'],
		['2010-03-20 05:28:30','74.162.17.73']
	];

	var charts_store = new Ext.data.JsonStore({
		fields:['hour', 'brutes', 'failed', 'blocked'],
		data: [
			{hour:'08:00', brutes:298, failed:2252, blocked:1050},
			{hour:'09:00', brutes:213, failed:2194, blocked:1061},
			{hour:'10:00', brutes:3496, failed:2361, blocked:1134},
			{hour:'11:00', brutes:3460, failed:2640, blocked:1267},
			{hour:'12:00', brutes:2946, failed:2289, blocked:1140},
			{hour:'13:00', brutes:3650, failed:2751, blocked:1324},
			{hour:'14:00', brutes:3239, failed:2394, blocked:1253},
			{hour:'15:00', brutes:3200, failed:2360, blocked:1155},
			{hour:'16:00', brutes:3636, failed:2755, blocked:1324},
			{hour:'17:00', brutes:4012, failed:352, blocked:1729},
			{hour:'18:00', brutes:3505, failed:243, blocked:1391},
			{hour:'19:00', brutes:3301, failed:2567, blocked:1354},
			{hour:'20:00', brutes:3277, failed:2385, blocked:11252},
			{hour:'21:00', brutes:3860, failed:3027, blocked:1565},
			{hour:'22:00', brutes:2945, failed:2554, blocked:1268},
			{hour:'23:00', brutes:3369, failed:2798, blocked:1320},
			{hour:'00:00', brutes:3404, failed:2340, blocked:1161},
			{hour:'01:00', brutes:3312, failed:2533, blocked:1306},
			{hour:'02:00', brutes:3084, failed:2409, blocked:1221},
			{hour:'03:00', brutes:3069, failed:2447, blocked:1255},
			{hour:'04:00', brutes:3629, failed:2719, blocked:1330},
			{hour:'05:00', brutes:3113, failed:2535, blocked:1293},
			{hour:'06:00', brutes:3658, failed:2743, blocked:1522},
			{hour:'07:00', brutes:3133, failed:2309, blocked:1353}
		]
	});

	var failed_store = new Ext.data.ArrayStore({
		fields: [
			{name: 'Date'},
			{name: 'IP address'},
			{name: 'Action'},
		]
	});

	failed_store.loadData(failed_data);

	var failed_grid = new Ext.grid.GridPanel({
		store: failed_store,
		columns: [
			{header: 'Date', width: 225},
			{header: 'IP address', width: 225},
			{header: 'Action', width: 225}
		],
		width: 905,
		height: 300,
		layout: 'fit',
		renderTo: 'main',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		title: 'Blocked IP adresses',      
	});
	
	var chart = new Ext.Panel({
		title: 'Blocked IP address statistics',
		width:440,
		height:220,
		style: {
			float: 'left',
			'margin': 5,
		},
		items: {
			xtype: 'linechart',
			store: charts_store,
			xField: 'hour',
			yField: 'brutes'
		},
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		renderTo: 'main'
	});
}
Ext.onReady(function(){
	Ext.QuickTips.init();
	Ext.form.Field.prototype.msgTarget = 'side';
	var SearchIP = new Ext.FormPanel({
		labelWidth: 75,
		frame:true,
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		title: 'IP address search',
		bodyStyle:'padding:5px 5px 5px',
		width: 350,
		defaults: {width: 230},
		defaultType: 'textfield',
		items: new Ext.form.TriggerField({
			id: 'ipaddr',
			name: 'ipaddr',
			fieldLabel: 'IP address',
			labelStyle: 'font-case:lower;',
			allowBlank:false,
			triggerClass: 'x-form-search-trigger',
			onTriggerClick: function(){
				var ipaddr = SearchIP.getForm().findField("ipaddr").getValue();
				ShowResults(ipaddr);
			}
		})
	});

SearchIP.render('main');
});