Ext.chart.Chart.CHART_URL = 'js/extjs/resources/charts.swf';

var VERSION = '0.0.1';

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
	layout: 'fit',
	bbar: {}
});

function get_parameter(name) {
	name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");
	var regexS = "[\\?&]"+name+"=([^&#]*)";
	var regex = new RegExp(regexS);
	var results = regex.exec(window.location.href);
	if (results == null) {
		return "";
	} else {
		return results[1];
	}
}

function CreateLink(value, action) {
	return value + " " + action;
}

function Show_Brutes() {
	Ext.MessageBox.show({
		msg: 'Loading, please wait...',
		progressText: 'Loading...',
		width:300,
		wait:true,
		waitConfig: {interval:200}
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
	
	brutes_store.setDefaultSort('date', 'desc');
	
	var brutes_grid = new Ext.grid.GridPanel({
		store: brutes_store,
		columns: [
			{header: 'Date', sortable: true, width: 250, dataIndex: 'date'},
			{header: 'IP address', sortable: true, width: 250, dataIndex: 'ip'},
			{header: 'Service', sortable: true, width: 240, dataIndex: 'service'}
		],
		width: 750,
		height: 480,
		viewConfig: { forceFit: true },
		loadMask: true,
		layout: 'fit',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
			'margin-bottom': '10px'
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
		waitConfig: {interval:200}
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
	failed_store.setDefaultSort('date', 'desc');
	
	var failed_grid = new Ext.grid.GridPanel({
		store: failed_store,
		columns: [
			{header: 'Date', width: 195, sortable: true, dataIndex: 'date'},
			{header: 'IP address', width: 195, sortable: true, dataIndex: 'ip'},
			{header: 'Service', width: 195, sortable: true, dataIndex: 'service'},
			{header: 'Username', width: 195, sortable: true, dataIndex: 'username'}
		],
		width: 750,
		height: 480,
		layout: 'fit',
		viewConfig: { forceFit: true },
		loadMask: true,
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
			'margin-bottom': '10px'
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
		waitConfig: {interval:200}
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
			{name: 'reason', mapping: 3}
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
						{header: 'Reason', width: 400}
					],
					width: 800,
					autoHeight: true,
					viewConfig: { forceFit: true },
					loadMask: true,
					style: {
						'margin-top': '10px',
						'margin-left': 'auto',
						'margin-right': 'auto'
					}
				});

				var charts_store = new Ext.data.JsonStore({
					autoLoad: true,
					url: base_url,
					baseParams: {
						id: '7',
						ip: ipaddr
					},
					fields: [
						{name: 'hour', mapping: 0},
						{name: 'brutes', mapping: 1, type: 'int'},
						{name: 'failed', mapping: 2, type: 'int'}
					]
				});

				var chart = new Ext.Panel({
					title: 'Brute/Failed attempts statistics for ' + ipaddr + ' (last 7 days)',
					width:440,
					height:220,
					style: {
						float: 'left',
						'margin': 5
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
							xAxis: {
								labelRotation: -15
							}
						},
						series: [{
							type: 'column',
							displayName: 'bruteforce attempts',
							yField: 'brutes',
							style: {
								color:0x6696e2
							}
						},{
							type:'column',
							displayName: 'failed attempts',
							yField: 'failed',
							style: {
								color: 0x256900
							}
						}]
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
		waitConfig: {interval:200}
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
							{header: 'Date', width: 195, sortable: true, dataIndex: 'date'},
							{header: 'IP address', width: 195, sortable: true, dataIndex: 'ip'}
						],
						width: 750,
						height: 480,
						layout: 'fit',
						viewConfig: { forceFit: true },
						loadMask: true,
						style: {
							'margin-top': '10px',
							'margin-left': 'auto',
							'margin-right': 'auto'
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
	services_store.setDefaultSort('date', 'desc');
}

function Show_IP_Details(ipaddr, interval) {
	Ext.MessageBox.show({
		msg: 'Loading, please wait...',
		progressText: 'Loading...',
		width:300,
		wait:true,
		waitConfig: {interval:200}
	});
	var details_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: base_url,
		baseParams: {
			id: '8',
			interval: interval,
			ip: ipaddr
		},
		root: 'data',
		totalProperty: 'total',
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
				}
			}
		}
	});
	details_store.setDefaultSort('date', 'desc');
	
	var details_grid = new Ext.grid.GridPanel({
		store: details_store,
		columns: [
			{header: 'Date', width: 195, sortable: true, dataIndex: 'date'},
			{header: 'IP address', width: 195, sortable: true, dataIndex: 'ip'},
			{header: 'Username', width: 195, sortable: true, dataIndex: 'username'},
			{header: 'Service', width: 195, sortable: true, dataIndex: 'service'}
		],
		width: 750,
		height: 480,
		layout: 'fit',
		viewConfig: { forceFit: true },
		loadMask: true,
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
			'margin-bottom': '10px'
		},
		bbar: {
			xtype: 'paging',
			id: 'pager',
			store: details_store,
			pageSize: 20,
			displayInfo: true,
			displayMsg: '',
			emptyMsg: ''
		}
	});

	CommonWin.removeAll();
	CommonWin.setTitle('IP address details');
	CommonWin.add(details_grid);
	CommonWin.doLayout();
	CommonWin.show();
}

function showBlocked() {
	Ext.MessageBox.show({
		msg: 'Loading, please wait...',
		progressText: 'Loading...',
		width:300,
		wait:true,
		waitConfig: {interval:200}
	});
	var blocked_store = new Ext.data.JsonStore({
		autoLoad: true,
		url: base_url,
		baseParams: {
			id: '9',
			limit: 10,
			start: 0
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
	blocked_store.setDefaultSort('date_from', 'desc');
	
	var blocked_grid = new Ext.grid.GridPanel({
		store: blocked_store,
		columns: [
			{header: 'From date', width: 150, sortable: true, dataIndex: 'date_from'},
			{header: 'To date', width: 150, sortable: true, dataIndex: 'date_to', renderer: function(value) {
					if (!value) {
						return "still active";
					} else {
						return value;
					}
				}
			},
			{header: 'IP address', width: 135, sortable: true, dataIndex: 'ip_addr'},
			{header: 'Reason', width: 315, sortable: true, dataIndex: 'reason'}
		],
		width: 750,
		height: 280,
		layout: 'fit',
		viewConfig: { forceFit: true },
		loadMask: true,
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
			'margin-bottom': '10px'
		},
		bbar: {
			xtype: 'paging',
			id: 'pager',
			store: blocked_store,
			pageSize: 10,
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

function goToMaster () {
	window.location = masterLink;
}

Ext.onReady(function(){
	var title_master = "";
	if (!get_parameter("local")) {
		title_master = "<a onclick='goToMaster();' href='javascript:void(0)'><b>Back to master interface</b></a>";
	}
	var charts = new Array();
	var charts_store;
	var chartsObj = new Object({
		options: [
			{title: '<a href="javascript:void(0);" onclick="Show_Brutes()">Bruteforce attempts statistics</a>', type: 'broots', name: 'bruteforce attempts', color: '0x6696e2'},
			{title: '<a href="javascript:void(0);" onclick="Show_Failed()">Failed login attempts</a>', type: 'failed_log', name: 'failed attempts', color: '0x256900'}
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
					'margin': 5
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
						xAxis: {
							labelRotation: -45,
							hideOverlappingLabels: false
						}
					},
					series: [{
						type: 'line',
						displayName: chartsObj.options[j].name,
						style: {
							color: chartsObj.options[j].color,
							size: config.chartDotSize,
							lineSize: config.chartLineSize
						}
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
			'margin-right': 'auto'
		},
		items: [{
				title: title_master,
				items: charts
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
						}
					},
					onTriggerClick: function(field) {
						ShowResults(this.getValue());
					}
				}), '->', {
						text: 'Show all blocked IPs',
						icon: 'images/blocked.gif',
						handler: function() {
							showBlocked();
						}
				}, '-'
			]
		}
	});
	
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
			{name: 'cPanel', mapping: "cpanel"},
			{name: 'DirectAdmin', mapping: "da"}
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
			},
			{header: 'DirectAdmin', width: 150, renderer: function(value) {
					return value == 0 ? value : '<a href="javascript:void(0)" onclick="Show_Services(6)">' + value + '</a>';
				}
			}
		],
		enableHdMenu: false,
		width: 905,
		height: 70,
		layout: 'fit',
		viewConfig: { forceFit: true },
		loadMask: true,
		style: {
			'margin-top': 'auto',
			'margin-left': 'auto',
			'margin-right': 'auto'
		},
		renderTo: 'main',
		title: 'Bruteforce attempts statistics per service'      
	});
	
	var summary_store;
	var summary_grid = new Array();
	var summaryObj = new Object({
 		options: [
			{interval: '1 hours', title: '1 hour summary'},
			{interval: '24 hours', title: 'Daily summary'},
			{interval: '1 weeks', title: 'Weekly summary'}
		]
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
				disableSelection: false,
				store: summary_store,
				columns: [
					{header: 'IP address', sortable: true, width: 135, dataIndex: 'ip'},
					{header: 'Count', sortable: true, width: 135, dataIndex: 'count'}
				],
				width: 290,
				height: 265,
				viewConfig: { forceFit: true },
				loadMask: true,
				style: {
					float: 'left',
					'margin': 5
				},
				title: summaryObj.options[i].title      
			})
		);
	}

	summary_grid[0].on('rowdblclick', function(grid, rowIndex, e) {
		record = grid.getStore().getAt(rowIndex).json;
		Show_IP_Details(record[1], summaryObj.options[0].interval);
	});
	summary_grid[1].on('rowdblclick', function(grid, rowIndex, e) {
		record = grid.getStore().getAt(rowIndex).json;
		Show_IP_Details(record[1], summaryObj.options[1].interval);
	});
	summary_grid[2].on('rowdblclick', function(grid, rowIndex, e) {
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
			'margin-bottom': '10px'
		},
		items: [{
				title: 'Summary report',
				items: summary_grid
		}]
	});
	
});
