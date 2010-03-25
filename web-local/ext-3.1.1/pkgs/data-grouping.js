/*
 * Ext JS Library 3.1.1
 * Copyright(c) 2006-2010 Ext JS, LLC
 * licensing@extjs.com
 * http://www.extjs.com/license
 */
Ext.data.GroupingStore=Ext.extend(Ext.data.Store,{constructor:function(a){Ext.data.GroupingStore.superclass.constructor.call(this,a);this.applyGroupField()},remoteGroup:false,groupOnSort:false,groupDir:"ASC",clearGrouping:function(){this.groupField=false;if(this.remoteGroup){if(this.baseParams){delete this.baseParams.groupBy;delete this.baseParams.groupDir}var a=this.lastOptions;if(a&&a.params){delete a.params.groupBy;delete a.params.groupDir}this.reload()}else{this.applySort();this.fireEvent("datachanged",this)}},groupBy:function(d,b,c){c=c?(String(c).toUpperCase()=="DESC"?"DESC":"ASC"):this.groupDir;if(this.groupField==d&&this.groupDir==c&&!b){return}this.groupField=d;this.groupDir=c;this.applyGroupField();if(this.groupOnSort){this.sort(d,c);return}if(this.remoteGroup){this.reload()}else{var a=this.sortInfo||{};if(b||a.field!=d||a.direction!=c){this.applySort()}else{this.sortData(d,c)}this.fireEvent("datachanged",this)}},applyGroupField:function(){if(this.remoteGroup){if(!this.baseParams){this.baseParams={}}Ext.apply(this.baseParams,{groupBy:this.groupField,groupDir:this.groupDir});var a=this.lastOptions;if(a&&a.params){Ext.apply(a.params,{groupBy:this.groupField,groupDir:this.groupDir})}}},applySort:function(){Ext.data.GroupingStore.superclass.applySort.call(this);if(!this.groupOnSort&&!this.remoteGroup){var a=this.getGroupState();if(a&&(a!=this.sortInfo.field||this.groupDir!=this.sortInfo.direction)){this.sortData(this.groupField,this.groupDir)}}},applyGrouping:function(a){if(this.groupField!==false){this.groupBy(this.groupField,true,this.groupDir);return true}else{if(a===true){this.fireEvent("datachanged",this)}return false}},getGroupState:function(){return this.groupOnSort&&this.groupField!==false?(this.sortInfo?this.sortInfo.field:undefined):this.groupField}});Ext.reg("groupingstore",Ext.data.GroupingStore);