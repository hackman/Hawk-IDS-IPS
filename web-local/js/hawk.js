Ext.chart.Chart.CHART_URL = '../js/extjs/resources/charts.swf';
var base_url = 'hawk.pl';

config = {
	chartLineSize: 1,
	chartDotSize: 5
}

var CommonWin = new Ext.Window({
	width:800,
	//height:400,
	autoHeight: true,
	shadow: true,
	resizable: false,
	closeAction: 'hide',
	modal: true,
	bbar: {}
});

function CreateLink(value, action) {
	return value + " " + action;
}

function Show_Brutes() {
	Ext.MessageBox.show({
		msg: 'Loading, please wait...',
		progressText: 'Loading...',
		width:300,
		wait:true,
		waitConfig: {interval:200},
	});
	var brutes_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: base_url,
		baseParams: {
			id: '4'
		},
		root: 'data',
		totalProperty: 'total',
		fields: [
			{name: 'date', mapping: 0},
			{name: 'ip', mapping: 1},
			{name: 'service', mapping: 2}
		],
		listeners: {
			load: function() {
				Ext.MessageBox.hide();
				if (brutes_store.getCount() == 0) {
					Ext.MessageBox.show({
						title: 'Info',
						msg: 'Entry not found!',
						buttons: Ext.MessageBox.OK,
						icon: 'ext-mb-info'
					});
					return;
				}
			}
		}
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
		},
		bbar: {
			xtype: 'paging',
			id: 'pager',
			store: brutes_store,
			pageSize: 20,
			displayInfo: true,
			displayMsg: '',
			emptyMsg: ''
		}
	});
	CommonWin.removeAll();
	CommonWin.setTitle('Bruteforce attempts (24 hrs only)');
	CommonWin.add(brutes_grid);
	CommonWin.doLayout();
	CommonWin.show();
}

function Show_Failed() {
	Ext.MessageBox.show({
		msg: 'Loading, please wait...',
		progressText: 'Loading...',
		width:300,
		wait:true,
		waitConfig: {interval:200},
	});
	var failed_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: base_url,
		baseParams: {
			id: '5'
		},
		root: 'data',
		totalProperty: 'total',
		fields: [
			{name: 'date', mapping: 0},
			{name: 'ip', mapping: 1},
			{name: 'service', mapping: 2},
			{name: 'username', mapping: 3}
		],
		listeners: {
			load: function() {
				Ext.MessageBox.hide();
				if (failed_store.getCount() == 0) {
					Ext.MessageBox.show({
						title: 'Info',
						msg: 'Entry not found!',
						buttons: Ext.MessageBox.OK,
						icon: 'ext-mb-info'
					});
					return;
				}
			}
		}
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
		},
		bbar: {
			xtype: 'paging',
			id: 'pager',
			store: failed_store,
			pageSize: 20,
			displayInfo: true,
			displayMsg: '',
			emptyMsg: ''
		}
	});

	CommonWin.removeAll();
	CommonWin.setTitle('Failed attempts (24 hrs only)');
	CommonWin.add(failed_grid);
	CommonWin.doLayout();
	CommonWin.show();
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
			msg: 'Incorrect IP address!',
			buttons: Ext.MessageBox.OK,
			icon: 'ext-mb-error'
		});
		return;
	}
	
	Ext.MessageBox.show({
		msg: 'Searching, please wait...',
		progressText: 'Searching...',
		width:300,
		wait:true,
		waitConfig: {interval:200},
		//icon:'ext-mb-info'
	});
	
	var search_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: base_url,
		baseParams: {
			id: '6',
			ip: ipaddr
		},
		fields: [
			{name: 'date_added', mapping: 0},
			{name: 'date_removed', mapping: 1},
			{name: 'ip', mapping: 2},
			{name: 'reason', mapping: 3},
		],
		listeners: {
			load: function() {
				Ext.MessageBox.hide();
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
						{header: 'Date removed', width: 125, renderer: function(value) {
								if (!value) {
									return "still active";
								} else {
									return value;
								}
							}
						},
						{header: 'IP address', width: 100},
						{header: 'Reason', width: 400},
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

				var charts_store = new Ext.data.JsonStore({
					autoLoad: true,
					url: base_url,
					baseParams: {
						id: '7'
					},
					fields: [
						{name: 'hour', mapping: 0},
						{name: 'brutes', mapping: 1, type: 'int'},
						{name: 'failed', mapping: 2, type: 'int'}
					]
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
							}
						},{
							type:'column',
							displayName: 'failed attempts',
							yField: 'failed',
							style: {
								color: 0x0000ff,
							}
						}],
			        })
				});
				CommonWin.removeAll();
				CommonWin.setTitle('Results');
				CommonWin.add([ search_grid, chart ]);
				CommonWin.doLayout();
				CommonWin.show();
			}
		}
	});
}

function Show_Services(type) {
	Ext.MessageBox.show({
		msg: 'Loading, please wait...',
		progressText: 'Loading...',
		width:300,
		wait:true,
		waitConfig: {interval:200},
	});
	var services_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: base_url,
		baseParams: {
			id: '1',
			service: type
		},
		fields: [
			{name: 'date', mapping: 0},
			{name: 'ip', mapping: 1}
		],
		listeners: {
			load: function() {
				Ext.MessageBox.hide();
				if (services_store.getCount() == 0) {
					Ext.MessageBox.show({
						title: 'Info',
						msg: 'Entry not found!',
						buttons: Ext.MessageBox.OK,
						icon: 'ext-mb-info'
					});
					return;
				} else {
					var services_grid = new Ext.grid.GridPanel({
						store: services_store,
						columns: [
							{header: 'Date', width: 195},
							{header: 'IP address', width: 195}
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

					CommonWin.removeAll();
					CommonWin.setTitle('Bruteforce attempts (24 hrs only)');
					CommonWin.add(services_grid);
					CommonWin.doLayout();
					CommonWin.show();
				}
			}
		}
	});
}

function Show_IP_Details(ipaddr, interval) {
	//alert(ipaddr + " " + interval);
	Ext.MessageBox.show({
		msg: 'Loading, please wait...',
		progressText: 'Loading...',
		width:300,
		wait:true,
		waitConfig: {interval:200},
	});
	var details_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: base_url,
		baseParams: {
			id: '8',
			interval: interval,
			ip: ipaddr
		},
		fields: [
			{name: 'date', mapping: 0},
			{name: 'ip', mapping: 1},
			{name: 'username', mapping: 2},
			{name: 'service', mapping: 3}
		],
		listeners: {
			load: function() {
				Ext.MessageBox.hide();
				if (details_store.getCount() == 0) {
					Ext.MessageBox.show({
						title: 'Info',
						msg: 'Entry not found!',
						buttons: Ext.MessageBox.OK,
						icon: 'ext-mb-info'
					});
					return;
				} else {
					var details_grid = new Ext.grid.GridPanel({
						store: details_store,
						columns: [
							{header: 'Date', width: 195},
							{header: 'IP address', width: 195},
							{header: 'Username', width: 195},
							{header: 'Service', width: 195}
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

					CommonWin.removeAll();
					CommonWin.setTitle('IP address details');
					CommonWin.add(details_grid);
					CommonWin.doLayout();
					CommonWin.show();
				}
			}
		}
	});
}

function showBlocked() {
	Ext.MessageBox.show({
		msg: 'Loading, please wait...',
		progressText: 'Loading...',
		width:300,
		wait:true,
		waitConfig: {interval:200},
	});
	var blocked_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: base_url,
		baseParams: {
			id: '9',
		},
		root: 'data',
		totalProperty: 'total',
		fields: [
			{name: 'date_from', mapping: 0},
			{name: 'date_to', mapping: 1},
			{name: 'ip_addr', mapping: 2},
			{name: 'reason', mapping: 3}
		],
		listeners: {
			load: function() {
				Ext.MessageBox.hide();
				if (blocked_store.getCount() == 0) {
					Ext.MessageBox.show({
						title: 'Info',
						msg: 'Entry not found!',
						buttons: Ext.MessageBox.OK,
						icon: 'ext-mb-info'
					});
					return;
				} 
			}
		}
	});
	var blocked_grid = new Ext.grid.GridPanel({
		store: blocked_store,
		columns: [
			{header: 'From date', width: 195},
			{header: 'To date', width: 195},
			{header: 'IP address', width: 195},
			{header: 'Reason', width: 195}
		],
		width: 750,
		height: 400,
		layout: 'fit',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		bbar: {
			xtype: 'paging',
			id: 'pager',
			store: blocked_store,
			pageSize: 20,
			displayInfo: true,
			displayMsg: '',
			emptyMsg: ''
		}
	});
	CommonWin.removeAll();
	CommonWin.setTitle('Blocked IP addresses');
	CommonWin.add(blocked_grid);
	CommonWin.doLayout();
	CommonWin.show();
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
			url: base_url,
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
		height: 300,
		layout: 'fit',
		renderTo: 'main',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		items: [{
				title: '<a href="http://hawk.sgadmins.com">Back to master interface</a>',
				items: charts,
		}],
		bbar:{
			items: ['-','<label for="ipaddr">Search for blocked IP address: </label>',
				new Ext.form.TriggerField({
					id: 'ipaddr',
					name: 'ipaddr',
					fieldLabel: 'Search for blocked IP address',
					labelStyle: 'font-case:lower;',
					//allowBlank:false,
					triggerClass: 'x-form-search-trigger',
					listeners : {
						specialkey : function(field, event) {
							if (Ext.EventObject.getKey(event) == event.ENTER) {
								ShowResults(field.getValue());
							};
						},
					},
					onTriggerClick: function(field) {
						ShowResults(this.getValue());
					}
				}), '->', {
					html: '<a href="javascript:void(0)" onClick="showBlocked()">Show all blocked IPs</a>'
				}, '-'
			]
		}
	});
	
	Ext.QuickTips.init();
	Ext.form.Field.prototype.msgTarget = 'side';
	/*var SearchIP = new Ext.FormPanel({
		labelWidth: 200,
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
			fieldLabel: 'Search for blocked IP address',
			labelStyle: 'font-case:lower;',
			//allowBlank:false,
			triggerClass: 'x-form-search-trigger',
			listeners : {
				specialkey : function(field, event) {
					if (Ext.EventObject.getKey(event) == event.ENTER) {
						ShowResults(field.getValue());
					};
				},
			},
			onTriggerClick: function(field) {
				ShowResults(this.getValue());
			}
		}),
			html: '<a href="javascript:void(0)" onClick="alert(\'hui\')">Show all blocked IPs</a>', handler: function() {
				alert('hui');
			}
	});*/
	
	var brute_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: base_url,
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
			{header: 'FTP', width: 150, renderer: function(value, metaData, record, rowIndex, colIndex, store) {
					return value == 0 ? value : '<a href="javascript:void(0)" onclick="Show_Services(0)">' + value + '</a>';
				}
			},
			{header: 'SSH', width: 150, renderer: function(value) {
					return value == 0 ? value : '<a href="javascript:void(0)" onclick="Show_Services(1)">' + value + '</a>';
				}
			},
			{header: 'POP3', width: 150, renderer: function(value) {
					return value == 0 ? value : '<a href="javascript:void(0)" onclick="Show_Services(2)">' + value + '</a>';
				}
			},
			{header: 'IMAP', width: 150, renderer: function(value) {
					return value == 0 ? value : '<a href="javascript:void(0)" onclick="Show_Services(3)">' + value + '</a>';
				}
			},
			{header: 'WebMail', width: 150, renderer: function(value) {
					return value == 0 ? value : '<a href="javascript:void(0)" onclick="Show_Services(4)">' + value + '</a>';
				}
			},
			{header: 'cPanel', width: 150, renderer: function(value) {
					return value == 0 ? value : '<a href="javascript:void(0)" onclick="Show_Services(5)">' + value + '</a>';
				}
			}
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
	var summaryObj = new Object({
 		options: [
			{interval: '1 hours', title: '1 hour summary'},
			{interval: '24 hours', title: 'Daily summary'},
			{interval: '1 weeks', title: 'Weekly summary'},
		],
	});
	for (var i=0; i<summaryObj.options.length; i++) {
		summary_store = new Ext.data.JsonStore({
			autoLoad: true,
			url: base_url,
			baseParams: {
				id: '2',
				interval: summaryObj.options[i].interval
			},
			fields: [
				{name: 'count', mapping: 0, type: 'int'},
				{name: 'ip', mapping: 1}
			]
		});
		summary_store.setDefaultSort('count', 'desc');
	
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

	summary_grid[0].on('rowclick', function(grid, rowIndex, e) {
		record = grid.getStore().getAt(rowIndex).json;
		Show_IP_Details(record[1], summaryObj.options[0].interval);
	});
	summary_grid[1].on('rowclick', function(grid, rowIndex, e) {
		record = grid.getStore().getAt(rowIndex).json;
		Show_IP_Details(record[1], summaryObj.options[1].interval);
	});
	summary_grid[2].on('rowclick', function(grid, rowIndex, e) {
		record = grid.getStore().getAt(rowIndex).json;
		Show_IP_Details(record[1], summaryObj.options[2].interval);
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