Ext.chart.Chart.CHART_URL = 'ext-3.1.1/resources/charts.swf';

var charts = new Array();
var summary_grid = new Array();

Ext.onReady(function(){
	var serv_data = [
		[20, 5, 13, 8, 21, 56]
	];
	var summary = [
		['125.65.7.3', '28'],
		['24.42.33.11', '4'],
		['24.99.104.193', '67'],
		['58.181.108.157', '32'],
		['67.235.226.74', '3'],
		['70.26.185.43', '44'],
		['71.118.16.242', '12'],
		['72.55.137.101', '3'],
		['74.55.182.98', '6'],
		['74.162.17.73', '81']
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
	
	charts[0] = new Ext.Panel({
		title: '<a href="hawk-brute.html">Bruteforce attempts statistics</a>',
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
		}
	});
	
	charts[1] = new Ext.Panel({
		title: '<a href="hawk-failed.html">Failed login attempts</a>',
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
			yField: 'failed'
		}
	});
	
	var chartsPanel = new Ext.Panel({
		id:'charts-panel',
		width: 905,
		height: 260,
		layout: 'fit',
		renderTo: 'main',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		items: [{
				title: 'Charts',
				items: charts,
		}]
	});
	
	var brute_store = new Ext.data.ArrayStore({
		fields: [
			{name: 'FTP'},
			{name: 'SSH'},
			{name: 'POP3'},
			{name: 'IMAP'},
			{name: 'WebMail'},
			{name: 'cPanel'}
		]
	});

	brute_store.loadData(serv_data);

	var brute_grid = new Ext.grid.GridPanel({
		store: brute_store,
		columns: [
			{header: 'FTP', width: 150},
			{header: 'SSH', width: 150},
			{header: 'POP3', width: 150},
			{header: 'IMAP', width: 150},
			{header: 'WebMail', width: 150},
			{header: 'cPanel', width: 150}
		],
		width: 905,
		height: 150,
		layout: 'fit',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		title: 'Bruteforce attempts statistics per service',      
	});

	brute_grid.render('main');
	
	var summary_store = new Ext.data.ArrayStore({
		fields: [
			{name: 'IP address'},
			{name: 'Count'}
		]
	});

	summary_store.loadData(summary);

	summary_grid[0] = new Ext.grid.GridPanel({
		store: summary_store,
		columns: [
			{header: 'IP address', width: 142},
			{header: 'Count', width: 142}
		],
		width: 290,
		height: 265,
		//layout: 'fit',
		style: {
			float: 'left',
			'margin': 5
		},
		title: '1 Hour summary',      
	});

	summary_grid[1] = new Ext.grid.GridPanel({
		store: summary_store,
		columns: [
			{header: 'IP address', width: 142},
			{header: 'Count', width: 142}
		],
		width: 290,
		height: 265,
		//layout: 'fit',
		style: {
			float: 'left',
			'margin': 5
		},
		title: 'Daily summary',      
	});

	summary_grid[2] = new Ext.grid.GridPanel({
		store: summary_store,
		columns: [
			{header: 'IP address', width: 142},
			{header: 'Count', width: 142}
		],
		width: 290,
		height: 265,
		//layout: 'fit',
		style: {
			float: 'left',
			'margin': 5
		},
		title: 'Weekly summary',      
	});

	var summaryPanel = new Ext.Panel({
		id:'summary-panel',
		width: 905,
		height: 305,
		layout: 'fit',
		renderTo: 'main',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
			'margin-bottom': '10px',
		},
		items: [{
				title: 'Summary report',
				items: summary_grid
		}]
	});
	
});