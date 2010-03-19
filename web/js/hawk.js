
var fieldValidator = function () {
	if (this.getValue() > 0) {
		return true;
	}
	return false;
}

Ext.onReady(function () {
	var stores = new Array();
	var charts = new Array();
	for (var i=0;i<4;i++) {
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
		items: [
			new Ext.form.NumberField({
				width: 40,
				id: 'min_brutes_i',
				labelStyle: 'width:150px',
				fieldLabel: 'Min bruteforce attempts',
				allowBlank: false,
				value: 11,//min_bruteforce,
				blankText:'Please enter a bruteforce attempts value',
				validator: fieldValidator,
			}),
			new Ext.form.NumberField({
				width: 40,
				id: 'max_brutes_i',
				labelStyle: 'width:150px',
				fieldLabel: 'Max bruteforce attempts',
				allowBlank: false,
				value: 11,//max_bruteforce,
				blankText:'Please enter a bruteforce attempts value',
				validator: fieldValidator,
			}),
			new Ext.form.NumberField({
				width: 40,
				id:'min_failed_i',
				labelStyle: 'width:150px',
				fieldLabel:'Min failed attempts',
				allowBlank: false,
				value: 11,//min_failed,
				blankText:'Please enter a failed attempts value',
				validator: fieldValidator,
			}),
			new Ext.form.NumberField({
				width: 40,
				id:'max_failed_i',
				labelStyle: 'width:150px',
				fieldLabel:'Max failed attempts',
				allowBlank: false,
				value: 11,//max_failed,
				blankText:'Please enter a failed attempts value',
				validator: fieldValidator,
			}),
			new Ext.form.NumberField({
				width: 40,
				id:'min_blocked_i',
				labelStyle: 'width:150px',
				fieldLabel:'Min blocked IP addresses',
				allowBlank:false,
				emptyText: 11,//min_blocked,
				validator: fieldValidator,
				blankText:'Please enter a blocked IP addresses count'
			}),
			new Ext.form.NumberField({
				width: 40,
				id:'max_blocked_i',
				labelStyle: 'width:150px',
				fieldLabel:'Max blocked IP addresses',
				allowBlank:false,
				emptyText: 11,//max_blocked,
				validator: fieldValidator,
				blankText:'Please enter a blocked IP addresses count'
			}),
			],
		buttons: [{
			text: "Save",
			formBind:true,
			handler: function() {
		  			if ( !Ext.getCmp('max_blocked_i').isValid() )
			  			alert('Queue: '+Ext.getCmp('max_blocked_i').getValue());
		  			else
						mySettings.hide();
				}
			},{
			text: "Close",
			formBind:true,
			handler: function() {
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
