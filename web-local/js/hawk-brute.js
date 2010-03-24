Ext.onReady(function(){
	var brute_data = [
		['2010-03-11 05:29:54', '125.65.7.3', 'FTP'],
		['2010-03-12 02:24:21','24.42.33.11', 'SSH'],
		['2010-03-13 08:21:09','24.99.104.193', 'POP3'],
		['2010-03-14 12:38:03','58.181.108.157', 'WebMail'],
		['2010-03-15 10:58:23','67.235.226.74', 'cPanel'],
		['2010-03-16 03:28:21','70.26.185.43', 'FTP'],
		['2010-03-17 04:46:01','71.118.16.242', 'SSH'],
		['2010-03-18 01:18:05','72.55.137.101', 'IMAP'],
		['2010-03-19 02:49:20','74.55.182.98', 'SSH'],
		['2010-03-20 05:28:30','74.162.17.73', 'SSH']
	];
	
	var brute_store = new Ext.data.ArrayStore({
		fields: [
			{name: 'Date'},
			{name: 'IP address'},
			{name: 'Service'}
		]
	});

	brute_store.loadData(brute_data);

	var brute_grid = new Ext.grid.GridPanel({
		store: brute_store,
		columns: [
			{header: 'Date', width: 300},
			{header: 'IP address', width: 300},
			{header: 'Service', width: 300}
		],
		width: 905,
		height: 300,
		layout: 'fit',
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		title: 'Bruteforce attempts (24 hrs only)',      
	});

	brute_grid.render('main');
});