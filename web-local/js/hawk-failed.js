Ext.onReady(function(){
	var failed_data = [
		['2010-03-11 05:29:54', '125.65.7.3', 'FTP', 'jonh'],
		['2010-03-12 02:24:21','24.42.33.11', 'SSH', 'jonh3'],
		['2010-03-13 08:21:09','24.99.104.193', 'POP3', 'jonh4'],
		['2010-03-14 12:38:03','58.181.108.157', 'WebMail', 'jonh5'],
		['2010-03-15 10:58:23','67.235.226.74', 'cPanel', 'jonh7'],
		['2010-03-16 03:28:21','70.26.185.43', 'FTP', 'jonh3'],
		['2010-03-17 04:46:01','71.118.16.242', 'SSH', 'jonh2'],
		['2010-03-18 01:18:05','72.55.137.101', 'IMAP', 'jonh3'],
		['2010-03-19 02:49:20','74.55.182.98', 'SSH', 'jonh4'],
		['2010-03-20 05:28:30','74.162.17.73', 'SSH', 'jonh1']
	];
	
	var failed_store = new Ext.data.ArrayStore({
		fields: [
			{name: 'Date'},
			{name: 'IP address'},
			{name: 'Service'},
			{name: 'username'},
		]
	});

	failed_store.loadData(failed_data);

	var failed_grid = new Ext.grid.GridPanel({
		store: failed_store,
		columns: [
			{header: 'Date', width: 225},
			{header: 'IP address', width: 225},
			{header: 'Service', width: 225},
			{header: 'Username', width: 225}
		],
		width: 905,
		height: 300,
		layout: 'fit',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		title: 'Failed attempts (24 hrs only)',      
	});

	failed_grid.render('main');
});