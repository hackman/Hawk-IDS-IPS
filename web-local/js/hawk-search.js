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
		style: {
			'margin-top': '10px',
			'margin-left': 'auto',
			'margin-right': 'auto',
		},
		title: 'Blocked IP adresses',      
	});

	failed_grid.render('main');
}
Ext.onReady(function(){
	Ext.QuickTips.init();
	Ext.form.Field.prototype.msgTarget = 'side';
	//SearchField.onTriggerClick = ShowResults();
	var SearchIP = new Ext.FormPanel({
		labelWidth: 75, // label settings here cascade unless overridden
		frame:true,
		title: 'IP address search',
		bodyStyle:'padding:5px 5px 0',
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
			//{
			//	fieldLabel: 'IP address',
			//	name: 'ipaddr',
			//	allowBlank:false,
			//},
	});

	//SearchIP.addButton('Search', function(){
	//	var ipaddr = SearchIP.getForm().findField("ipaddr").getValue();
	//	ShowResults(ipaddr);
	//});

SearchIP.render('main');
});