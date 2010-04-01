Ext.chart.Chart.CHART_URL = 'ext-3.1.1/resources/charts.swf';
var base_url = '/~sentry/cgi-bin/jivko/';

config = {
	chartLineSize: 1,
	chartDotSize: 5,
}

function Show_Brutes() {
	var brutes_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: '../cgi-bin/jivko/hawk.pl',
		baseParams: {
			id: '4'
		},
		fields: [
			{name: 'date', mapping: 0},
			{name: 'ip', mapping: 1},
			{name: 'service', mapping: 2}
		]
	});

	var brutes_grid = new Ext.grid.GridPanel({
		store: brutes_store,
		columns: [
			{header: 'Date', width: 250},
			{header: 'IP address', width: 250},
			{header: 'Service', width: 250}
		],
		width: 750,
		height: 400,
		layout: 'fit',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		}
	});
	
		var BrutesWin = new Ext.Window({
			width:800,
			height:400,
			shadow: true,
			id: 'results',
			title: 'Bruteforce attempts (24 hrs only)',
			resizable: false,
			items: brutes_grid
		});
	BrutesWin.show();
}

function Show_Failed() {
	var failed_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: '../cgi-bin/jivko/hawk.pl',
		baseParams: {
			id: '5'
		},
		fields: [
			{name: 'date', mapping: 0},
			{name: 'ip', mapping: 1},
			{name: 'service', mapping: 2},
			{name: 'username', mapping: 3}
		]
	});

	var failed_grid = new Ext.grid.GridPanel({
		store: failed_store,
		columns: [
			{header: 'Date', width: 195},
			{header: 'IP address', width: 195},
			{header: 'Service', width: 195},
			{header: 'Username', width: 195}
		],
		width: 750,
		height: 400,
		layout: 'fit',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		}
	});
	
	var FailedWin = new Ext.Window({
		width:800,
		height:400,
		shadow: true,
		id: 'results',
		title: 'Failed attempts (24 hrs only)',
		resizable: false,
		items: failed_grid
	});
	FailedWin.show();
}

function ShowResults(ipaddr) {
	var Validate_RegExp = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$";
	if (!ipaddr) {
		Ext.MessageBox.show({
			title: 'Error',
			msg: 'There is no IP address entered!',
			buttons: Ext.MessageBox.OK,
			icon: 'ext-mb-error'
		});
		return;
	}
	if (ipaddr.match(Validate_RegExp) == null) {
		Ext.MessageBox.show({
			title: 'Error',
			msg: 'Icorrect IP address!',
			buttons: Ext.MessageBox.OK,
			icon: 'ext-mb-error'
		});
		return;
	}
	
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
	
	var search_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: '../cgi-bin/jivko/hawk.pl',
		baseParams: {
			id: '6',
			ip: ipaddr
		},
		fields: [
			{name: 'date_added', mapping: 0},
			{name: 'date_removed', mapping: 1},
			{name: 'ip', mapping: 2},
			{name: 'reason', mapping: 3},
		]
	});
	
	if (search_store.getCount() == 0) {
		Ext.MessageBox.show({
			title: 'Info',
			msg: 'IP address not found!',
			buttons: Ext.MessageBox.OK,
			icon: 'ext-mb-info'
		});
		return;
	}

	var search_grid = new Ext.grid.GridPanel({
		store: search_store,
		columns: [
			{header: 'Date added', width: 125},
			{header: 'Date removed', width: 125},
			{header: 'IP address', width: 100},
			{header: 'Reason', width: 400},
			//{header: 'Action', width: 205, renderer: function(value, metaData, record, rowIndex, colIndex, store){ return '<a href="#" onclick="alert(record)">Unblock</a>';}}
		],
		width: 800,
		height: 50,
		layout: 'fit',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
	});
	
	var chart = new Ext.Panel({
		title: 'Brute/Failed attempts statistics',
		width:440,
		height:220,
		style: {
			float: 'left',
			'margin': 5,
		},
		items:  new Ext.chart.LineChart({
			store: charts_store,
			xField: 'hour',
			//height: '220px',
			//width: '438px',
			extraStyle: {
				legend: {
					display: 'bottom'
				},
			},
			series: [{
				type: 'column',
				displayName: 'bruteforce attempts',
				yField: 'brutes',
				style: {
					color:0xff0000,
					size: config.chartDotSize,
					lineSize: config.chartLineSize,
				}
			},{
				type:'column',
				displayName: 'failed attempts',
				yField: 'failed',
				style: {
					color: 0x00ff00,
					size: config.chartDotSize,
					lineSize: config.chartLineSize,
				}
			}],
        })
	});
	
	var ResultsWin = new Ext.Window({
		width:800,
		height:400,
		shadow: true,
		id: 'results',
		title:"Results",
		resizable: false,
		items: [ search_grid, chart ]
	});
	ResultsWin.show();	
}

Ext.onReady(function(){
	var charts = new Array();
	var charts_store;
	var chartsObj = new Object({
		options: [
			{title: '<a href="javascript:void(0);" onclick="Show_Brutes()">Bruteforce attempts statistics</a>', type: 'broots', name: 'bruteforce attempts', color: '0xff0000'},
			{title: '<a href="javascript:void(0);" onclick="Show_Failed()">Failed login attempts</a>', type: 'failed_log', name: 'failed attempts', color: '0x0000ff'}
		]
	});
	
	for (var j=0; j<chartsObj.options.length; j++) {
		charts_store = new Ext.data.JsonStore({
			autoLoad: true,
			url: '../cgi-bin/jivko/hawk.pl',
			baseParams: {
				id: '3',
				type: chartsObj.options[j].type
			},
			fields: [
				{name: 'count', mapping: 0, type: 'int'},
				{name: 'hour', mapping: 1}
			]
		});
		charts.push(new Ext.Panel({
				title: chartsObj.options[j].title,
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
					yField: 'count',
					extraStyle: {
						legend: {
							display: 'bottom'
						},
					},
					series: [{
						type: 'line',
						displayName: chartsObj.options[j].name,
						style: {
							color: chartsObj.options[j].color,
							size: config.chartDotSize,
							lineSize: config.chartLineSize,
						},
					}]	
				}
			})
		);
	}
	
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
	
	Ext.QuickTips.init();
	Ext.form.Field.prototype.msgTarget = 'side';
	var SearchIP = new Ext.FormPanel({
		labelWidth: 75,
		frame:true,
		style: {
			'margin-top': 'auto',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		//title: 'IP address search',
		bodyStyle:'padding:5px 5px 0px',
		width: 905,
		defaults: {width: 200},
		defaultType: 'textfield',
		renderTo: 'main',
		items: new Ext.form.TriggerField({
			id: 'ipaddr',
			name: 'ipaddr',
			fieldLabel: 'IP address',
			labelStyle: 'font-case:lower;',
			//allowBlank:false,
			triggerClass: 'x-form-search-trigger',
			onTriggerClick: function(){
				var ipaddr = SearchIP.getForm().findField("ipaddr").getValue();
				ShowResults(ipaddr);
			}
		})
	});
	
	var brute_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: '../cgi-bin/jivko/hawk.pl',
		baseParams: {
			id: 1
		},
		idProperty: 'ftp',
		fields: [
			{name: 'FTP', mapping: "ftp"},
			{name: 'SSH', mapping: "ssh"},
			{name: 'POP3', mapping: "pop3"},
			{name: 'IMAP', mapping: "imap"},
			{name: 'WebMail', mapping: "webmail"},
			{name: 'cPanel', mapping: "cpanel"}
		]
	});

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
		enableHdMenu: false,
		width: 905,
		height: 70,
		layout: 'fit',
		style: {
			'margin-top': 'auto',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		renderTo: 'main',
		title: 'Bruteforce attempts statistics per service',      
	});
	
	var summary_store;
	var summary_grid = new Array();
	summaryObj = new Object({
		options: [
			{interval: '1 hours', title: '1 hour summary'},
			{interval: '24 hours', title: 'Daily summary'},
			{interval: '1 weeks', title: 'Weekly summary'},
		]
	});
	for (var i=0; i<summaryObj.options.length; i++) {
		summary_store = new Ext.data.JsonStore({
			autoLoad: true,
			url: '../cgi-bin/jivko/hawk.pl',
			baseParams: {
				id: '2',
				interval: summaryObj.options[i].interval
			},
			fields: [
				{name: 'count', mapping: 0},
				{name: 'ip', mapping: 1}
			]
		});
	
		summary_grid.push(new Ext.grid.GridPanel({
				store: summary_store,
				columns: [
					{header: 'IP address', sortable: true, width: 135, dataIndex: 'ip'},
					{header: 'Count', sortable: true, width: 135, dataIndex: 'count'}
				],
				width: 290,
				height: 265,
				style: {
					float: 'left',
					'margin': 5
				},
				title: summaryObj.options[i].title,      
			})
		);
	}

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