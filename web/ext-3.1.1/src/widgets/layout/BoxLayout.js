/*!
 * Ext JS Library 3.1.1
 * Copyright(c) 2006-2010 Ext JS, LLC
 * licensing@extjs.com
 * http://www.extjs.com/license
 */
/**
 * @class Ext.layout.BoxLayout
 * @extends Ext.layout.ContainerLayout
 * <p>Base Class for HBoxLayout and VBoxLayout Classes. Generally it should not need to be used directly.</p>
 */
Ext.layout.BoxLayout = Ext.extend(Ext.layout.ContainerLayout, {
    /**
     * @cfg {Object} defaultMargins
     * <p>If the individual contained items do not have a <tt>margins</tt>
     * property specified, the default margins from this property will be
     * applied to each item.</p>
     * <br><p>This property may be specified as an object containing margins
     * to apply in the format:</p><pre><code>
{
    top: (top margin),
    right: (right margin),
    bottom: (bottom margin),
    left: (left margin)
}</code></pre>
     * <p>This property may also be specified as a string containing
     * space-separated, numeric margin values. The order of the sides associated
     * with each value matches the way CSS processes margin values:</p>
     * <div class="mdetail-params"><ul>
     * <li>If there is only one value, it applies to all sides.</li>
     * <li>If there are two values, the top and bottom borders are set to the
     * first value and the right and left are set to the second.</li>
     * <li>If there are three values, the top is set to the first value, the left
     * and right are set to the second, and the bottom is set to the third.</li>
     * <li>If there are four values, they apply to the top, right, bottom, and
     * left, respectively.</li>
     * </ul></div>
     * <p>Defaults to:</p><pre><code>
     * {top:0, right:0, bottom:0, left:0}
     * </code></pre>
     */
    defaultMargins : {left:0,top:0,right:0,bottom:0},
    /**
     * @cfg {String} padding
     * <p>Sets the padding to be applied to all child items managed by this layout.</p>
     * <p>This property must be specified as a string containing
     * space-separated, numeric padding values. The order of the sides associated
     * with each value matches the way CSS processes padding values:</p>
     * <div class="mdetail-params"><ul>
     * <li>If there is only one value, it applies to all sides.</li>
     * <li>If there are two values, the top and bottom borders are set to the
     * first value and the right and left are set to the second.</li>
     * <li>If there are three values, the top is set to the first value, the left
     * and right are set to the second, and the bottom is set to the third.</li>
     * <li>If there are four values, they apply to the top, right, bottom, and
     * left, respectively.</li>
     * </ul></div>
     * <p>Defaults to: <code>"0"</code></p>
     */
    padding : '0',
    // documented in subclasses
    pack : 'start',

    // private
    monitorResize : true,
    type: 'box',
    scrollOffset : 0,
    extraCls : 'x-box-item',
    targetCls : 'x-box-layout-ct',
    innerCls : 'x-box-inner',

    constructor : function(config){
        Ext.layout.BoxLayout.superclass.constructor.call(this, config);
        if(Ext.isString(this.defaultMargins)){
            this.defaultMargins = this.parseMargins(this.defaultMargins);
        }
    },

    // private
    isValidParent : function(c, target){
        return this.innerCt && c.getPositionEl().dom.parentNode == this.innerCt.dom;
    },

    // private
    renderAll : function(ct, target){
        if(!this.innerCt){
            // the innerCt prevents wrapping and shuffling while
            // the container is resizing
            this.innerCt = target.createChild({cls:this.innerCls});
            this.padding = this.parseMargins(this.padding);
        }
        Ext.layout.BoxLayout.superclass.renderAll.call(this, ct, this.innerCt);
    },

    onLayout : function(ct, target){
        this.renderAll(ct, target);
    },

    getLayoutTargetSize : function(){
        var target = this.container.getLayoutTarget(), ret;
        if (target) {
            ret = target.getViewSize();
            ret.width -= target.getPadding('lr');
            ret.height -= target.getPadding('tb');
        }
        return ret;
    },

    // private
    renderItem : function(c){
        if(Ext.isString(c.margins)){
            c.margins = this.parseMargins(c.margins);
        }else if(!c.margins){
            c.margins = this.defaultMargins;
        }
        Ext.layout.BoxLayout.superclass.renderItem.apply(this, arguments);
    }
});

/**
 * @class Ext.layout.VBoxLayout
 * @extends Ext.layout.BoxLayout
 * <p>A layout that arranges items vertically down a Container. This layout optionally divides available vertical
 * space between child items containing a numeric <code>flex</code> configuration.</p>
 * This layout may also be used to set the widths of child items by configuring it with the {@link #align} option.
 */
Ext.layout.VBoxLayout = Ext.extend(Ext.layout.BoxLayout, {
    /**
     * @cfg {String} align
     * Controls how the child items of the container are aligned. Acceptable configuration values for this
     * property are:
     * <div class="mdetail-params"><ul>
     * <li><b><tt>left</tt></b> : <b>Default</b><div class="sub-desc">child items are aligned horizontally
     * at the <b>left</b> side of the container</div></li>
     * <li><b><tt>center</tt></b> : <div class="sub-desc">child items are aligned horizontally at the
     * <b>mid-width</b> of the container</div></li>
     * <li><b><tt>stretch</tt></b> : <div class="sub-desc">child items are stretched horizontally to fill
     * the width of the container</div></li>
     * <li><b><tt>stretchmax</tt></b> : <div class="sub-desc">child items are stretched horizontally to
     * the size of the largest item.</div></li>
     * </ul></div>
     */
    align : 'left', // left, center, stretch, strechmax
    type: 'vbox',
    /**
     * @cfg {String} pack
     * Controls how the child items of the container are packed together. Acceptable configuration values
     * for this property are:
     * <div class="mdetail-params"><ul>
     * <li><b><tt>start</tt></b> : <b>Default</b><div class="sub-desc">child items are packed together at
     * <b>top</b> side of container</div></li>
     * <li><b><tt>center</tt></b> : <div class="sub-desc">child items are packed together at
     * <b>mid-height</b> of container</div></li>
     * <li><b><tt>end</tt></b> : <div class="sub-desc">child items are packed together at <b>bottom</b>
     * side of container</div></li>
     * </ul></div>
     */
    /**
     * @cfg {Number} flex
     * This configuation option is to be applied to <b>child <tt>items</tt></b> of the container managed
     * by this layout. Each child item with a <tt>flex</tt> property will be flexed <b>vertically</b>
     * according to each item's <b>relative</b> <tt>flex</tt> value compared to the sum of all items with
     * a <tt>flex</tt> value specified.  Any child items that have either a <tt>flex = 0</tt> or
     * <tt>flex = undefined</tt> will not be 'flexed' (the initial size will not be changed).
     */

    // private
    onLayout : function(ct, target){
        Ext.layout.VBoxLayout.superclass.onLayout.call(this, ct, target);

        var cs = this.getRenderedItems(ct), csLen = cs.length,
            c, i, cm, ch, margin, cl, diff, aw, availHeight,
            size = this.getLayoutTargetSize(),
            w = size.width,
            h = size.height - this.scrollOffset,
            l = this.padding.left,
            t = this.padding.top,
            isStart = this.pack == 'start',
            extraHeight = 0,
            maxWidth = 0,
            totalFlex = 0,
            usedHeight = 0,
            idx = 0,
            heights = [],
            restore = [];

        // Do only width calculations and apply those first, as they can affect height
        for (i = 0 ; i < csLen; i++) {
            c = cs[i];
            cm = c.margins;
            margin = cm.top + cm.bottom;
            // Max height for align
            maxWidth = Math.max(maxWidth, c.getWidth() + cm.left + cm.right);
        }

        var innerCtWidth = maxWidth + this.padding.left + this.padding.right;
        switch(this.align){
            case 'stretch':
                this.innerCt.setSize(w, h);
                break;
            case 'stretchmax':
            case 'left':
                this.innerCt.setSize(innerCtWidth, h);
                break;
            case 'center':
                this.innerCt.setSize(w = Math.max(w, innerCtWidth), h);
                break;
        }

        var availableWidth = Math.max(0, w - this.padding.left - this.padding.right);
        // Apply widths
        for (i = 0 ; i < csLen; i++) {
            c = cs[i];
            cm = c.margins;
            if(this.align == 'stretch'){
                c.setWidth(((w - (this.padding.left + this.padding.right)) - (cm.left + cm.right)).constrain(
                    c.minWidth || 0, c.maxWidth || 1000000));
            }else if(this.align == 'stretchmax'){
                c.setWidth((maxWidth - (cm.left + cm.right)).constrain(
                    c.minWidth || 0, c.maxWidth || 1000000));
            }else if(isStart && c.flex){
                c.setWidth();
            }

        }

        // Height calculations
        for (i = 0 ; i < csLen; i++) {
            c = cs[i];
            // Total of all the flex values
            totalFlex += c.flex || 0;
            // Don't run height calculations on flexed items
            if (!c.flex) {
                // Render and layout sub-containers without a flex or height, once
                if (!c.height && !c.hasLayout && c.doLayout) {
                    c.doLayout();
                }
                ch = c.getHeight();
            } else {
                ch = 0;
            }

            cm = c.margins;
            // Determine how much height is available to flex
            extraHeight += ch + cm.top + cm.bottom;
        }
        // Final avail height calc
        availHeight = Math.max(0, (h - extraHeight - this.padding.top - this.padding.bottom));

        var leftOver = availHeight;
        for (i = 0 ; i < csLen; i++) {
            c = cs[i];
            if(isStart && c.flex){
                ch = Math.floor(availHeight * (c.flex / totalFlex));
                leftOver -= ch;
                heights.push(ch);
            }
        }
        if(this.pack == 'center'){
            t += availHeight ? availHeight / 2 : 0;
        }else if(this.pack == 'end'){
            t += availHeight;
        }
        idx = 0;
        // Apply heights
        for (i = 0 ; i < csLen; i++) {
            c = cs[i];
            cm = c.margins;
            t += cm.top;
            aw = availableWidth;
            cl = l + cm.left // default left pos

            // Adjust left pos for centering
            if(this.align == 'center'){
                if((diff = availableWidth - (c.getWidth() + cm.left + cm.right)) > 0){
                    cl += (diff/2);
                    aw -= diff;
                }
            }

            c.setPosition(cl, t);
            if(isStart && c.flex){
                ch = Math.max(0, heights[idx++] + (leftOver-- > 0 ? 1 : 0));
                c.setSize(aw, ch);
            }else{
                ch = c.getHeight();
            }
            t += ch + cm.bottom;
        }
        // Putting a box layout into an overflowed container is NOT correct and will make a second layout pass necessary.
        if (i = target.getStyle('overflow') && i != 'hidden' && !this.adjustmentPass) {
            var ts = this.getLayoutTargetSize();
            if (ts.width != size.width || ts.height != size.height){
                this.adjustmentPass = true;
                this.onLayout(ct, target);
            }
        }
        delete this.adjustmentPass;
    }
});

Ext.Container.LAYOUTS.vbox = Ext.layout.VBoxLayout;

/**
 * @class Ext.layout.HBoxLayout
 * @extends Ext.layout.BoxLayout
 * <p>A layout that arranges items horizontally across a Container. This layout optionally divides available horizontal
 * space between child items containing a numeric <code>flex</code> configuration.</p>
 * This layout may also be used to set the heights of child items by configuring it with the {@link #align} option.
 */
Ext.layout.HBoxLayout = Ext.extend(Ext.layout.BoxLayout, {
    /**
     * @cfg {String} align
     * Controls how the child items of the container are aligned. Acceptable configuration values for this
     * property are:
     * <div class="mdetail-params"><ul>
     * <li><b><tt>top</tt></b> : <b>Default</b><div class="sub-desc">child items are aligned vertically
     * at the <b>top</b> of the container</div></li>
     * <li><b><tt>middle</tt></b> : <div class="sub-desc">child items are aligned vertically in the
     * <b>middle</b> of the container</div></li>
     * <li><b><tt>stretch</tt></b> : <div class="sub-desc">child items are stretched vertically to fill
     * the height of the container</div></li>
     * <li><b><tt>stretchmax</tt></b> : <div class="sub-desc">child items are stretched vertically to
     * the height of the largest item.</div></li>
     */
    align : 'top', // top, middle, stretch, strechmax
    type: 'hbox',
    /**
     * @cfg {String} pack
     * Controls how the child items of the container are packed together. Acceptable configuration values
     * for this property are:
     * <div class="mdetail-params"><ul>
     * <li><b><tt>start</tt></b> : <b>Default</b><div class="sub-desc">child items are packed together at
     * <b>left</b> side of container</div></li>
     * <li><b><tt>center</tt></b> : <div class="sub-desc">child items are packed together at
     * <b>mid-width</b> of container</div></li>
     * <li><b><tt>end</tt></b> : <div class="sub-desc">child items are packed together at <b>right</b>
     * side of container</div></li>
     * </ul></div>
     */
    /**
     * @cfg {Number} flex
     * This configuation option is to be applied to <b>child <tt>items</tt></b> of the container managed
     * by this layout. Each child item with a <tt>flex</tt> property will be flexed <b>horizontally</b>
     * according to each item's <b>relative</b> <tt>flex</tt> value compared to the sum of all items with
     * a <tt>flex</tt> value specified.  Any child items that have either a <tt>flex = 0</tt> or
     * <tt>flex = undefined</tt> will not be 'flexed' (the initial size will not be changed).
     */

    // private
    onLayout : function(ct, target){
        Ext.layout.HBoxLayout.superclass.onLayout.call(this, ct, target);

        var cs = this.getRenderedItems(ct), csLen = cs.length,
            c, i, cm, cw, ch, diff, availWidth,
            size = this.getLayoutTargetSize(),
            w = size.width - this.scrollOffset,
            h = size.height,
            l = this.padding.left,
            t = this.padding.top,
            isStart = this.pack == 'start',
            isRestore = ['stretch', 'stretchmax'].indexOf(this.align) == -1,
            extraWidth = 0,
            maxHeight = 0,
            totalFlex = 0,
            usedWidth = 0;

        for (i = 0 ; i < csLen; i++) {
            c = cs[i];
            // Total of all the flex values
            totalFlex += c.flex || 0;
            // Don't run width calculations on flexed items
            if (!c.flex) {
                // Render and layout sub-containers without a flex or width, once
                if (!c.width && !c.hasLayout && c.doLayout) {
                    c.doLayout();
                }
                cw = c.getWidth();
            } else {
                cw = 0;
            }
            cm = c.margins;
            // Determine how much width is available to flex
            extraWidth += cw + cm.left + cm.right;
            // Max height for align
            maxHeight = Math.max(maxHeight, c.getHeight() + cm.top + cm.bottom);
        }
        // Final avail width calc
        availWidth = Math.max(0, (w - extraWidth - this.padding.left - this.padding.right));

        var innerCtHeight = maxHeight + this.padding.top + this.padding.bottom;
        switch(this.align){
            case 'stretch':
                this.innerCt.setSize(w, h);
                break;
            case 'stretchmax':
            case 'top':
                this.innerCt.setSize(w, innerCtHeight);
                break;
            case 'middle':
                this.innerCt.setSize(w, h = Math.max(h, innerCtHeight));
                break;
        }

        var leftOver = availWidth,
            widths = [],
            restore = [],
            idx = 0,
            availableHeight = Math.max(0, h - this.padding.top - this.padding.bottom);

        for (i = 0 ; i < csLen; i++) {
            c = cs[i];
            if(isStart && c.flex){
                cw = Math.floor(availWidth * (c.flex / totalFlex));
                leftOver -= cw;
                widths.push(cw);
            }
        }

        if(this.pack == 'center'){
            l += availWidth ? availWidth / 2 : 0;
        }else if(this.pack == 'end'){
            l += availWidth;
        }
        for (i = 0 ; i < csLen; i++) {
            c = cs[i];
            cm = c.margins;
            l += cm.left;
            c.setPosition(l, t + cm.top);
            if(isStart && c.flex){
                cw = Math.max(0, widths[idx++] + (leftOver-- > 0 ? 1 : 0));
                if(isRestore){
                    restore.push(c.getHeight());
                }
                c.setSize(cw, availableHeight);
            }else{
                cw = c.getWidth();
            }
            l += cw + cm.right;
        }

        idx = 0;
        for (i = 0 ; i < csLen; i++) {
            c = cs[i];
            cm = c.margins;
            ch = c.getHeight();
            if(isStart && c.flex){
                ch = restore[idx++];
            }
            if(this.align == 'stretch'){
                c.setHeight(((h - (this.padding.top + this.padding.bottom)) - (cm.top + cm.bottom)).constrain(
                    c.minHeight || 0, c.maxHeight || 1000000));
            }else if(this.align == 'stretchmax'){
                c.setHeight((maxHeight - (cm.top + cm.bottom)).constrain(
                    c.minHeight || 0, c.maxHeight || 1000000));
            }else{
                if(this.align == 'middle'){
                    diff = availableHeight - (ch + cm.top + cm.bottom);
                    ch = t + cm.top + (diff/2);
                    if(diff > 0){
                        c.setPosition(c.x, ch);
                    }
                }
                if(isStart && c.flex){
                    c.setHeight(ch);
                }
            }
        }
        // Putting a box layout into an overflowed container is NOT correct and will make a second layout pass necessary.
        if (i = target.getStyle('overflow') && i != 'hidden' && !this.adjustmentPass) {
            var ts = this.getLayoutTargetSize();
            if (ts.width != size.width || ts.height != size.height){
                this.adjustmentPass = true;
                this.onLayout(ct, target);
            }
        }
        delete this.adjustmentPass;
    }
});

Ext.Container.LAYOUTS.hbox = Ext.layout.HBoxLayout;
