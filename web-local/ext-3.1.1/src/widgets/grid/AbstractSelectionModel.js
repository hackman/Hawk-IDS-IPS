/*!
 * Ext JS Library 3.1.1
 * Copyright(c) 2006-2010 Ext JS, LLC
 * licensing@extjs.com
 * http://www.extjs.com/license
 */
/**
 * @class Ext.grid.AbstractSelectionModel
 * @extends Ext.util.Observable
 * Abstract base class for grid SelectionModels.  It provides the interface that should be
 * implemented by descendant classes.  This class should not be directly instantiated.
 * @constructor
 */
Ext.grid.AbstractSelectionModel = Ext.extend(Ext.util.Observable,  {
    /**
     * The GridPanel for which this SelectionModel is handling selection. Read-only.
     * @type Object
     * @property grid
     */
    
    constructor : function(){
        this.locked = false;
        Ext.grid.AbstractSelectionModel.superclass.constructor.call(this);
    },

    /** @ignore Called by the grid automatically. Do not call directly. */
    init : function(grid){
        this.grid = grid;
        this.initEvents();
    },

    /**
     * Locks the selections.
     */
    lock : function(){
        this.locked = true;
    },

    /**
     * Unlocks the selections.
     */
    unlock : function(){
        this.locked = false;
    },

    /**
     * Returns true if the selections are locked.
     * @return {Boolean}
     */
    isLocked : function(){
        return this.locked;
    },
    
    destroy: function(){
        this.purgeListeners();
    }
});