module JqGridSubGrid
  def generate_sub_grid
    javascript = ""
    javascript << sub_grid_inline_edit
    javascript << direct_link(sub_grid)
    javascript <<  <<-JAVASCRIPT
        subGridRowExpanded: function(subgrid_id, row_id) {
        		var subgrid_table_id, pager_id;
        		subgrid_table_id = subgrid_id+"_t";
        		pager_id = "p_"+subgrid_table_id;
        		$("#"+subgrid_id).html("<table id='"+subgrid_table_id+"' class='scroll'></table><div id='"+pager_id+"' class='scroll'></div>");
        		jQuery("#"+subgrid_table_id).jqGrid(
              {
        			url: "#{sub_grid[:url]}?q=2&id="+row_id,
              editurl: '#{sub_grid[:edit_url]}?parent_id='+row_id,
              datatype: "json",
              colNames: #{sub_grid[:column_names]},
              colModel: #{sub_grid[:column_model]},
              rowNum:#{sub_grid[:rows_per_page]},
              pager: pager_id,
              imgpath: '/images/themes/lightness/images',
              multiselect: #{sub_grid[:multi_select]},
              sortname: '#{sub_grid[:sort_column]}',
              sortorder: '#{sub_grid[:sort_order]}',
              viewrecords: true,
              viewsortcols: true,
              toolbar : [true,"top"],
              #{sub_grid[:inline_edit]}
              #{direct_link sub_grid}
              #{sub_grid[:multiselect]}
              height: '100%'
              })
    JAVASCRIPT

    javascript << sub_grid_nav
  end

  def sub_grid_nav
    <<-JAVASCRIPT
      .navGrid("#"+pager_id,
        {
        refresh:#{sub_grid[:refresh]},
        edit:#{sub_grid[:edit]},
        add:#{sub_grid[:add]},
        del:#{sub_grid[:delete]},
        search:false
        })
      .navButtonAdd("#"+pager_id,
        {
        caption:"Search",title:"Toggle Search",buttonimg:'/images/jqgrid/search.png',
          onClickButton:function() {
            if(jQuery("#t_"+subgrid_table_id).css("display")=="none") {
              jQuery("#t_"+subgrid_table_id).css("display","");
            } else {
              jQuery("#t_"+subgrid_table_id).css("display","none");
            }
          }
        });
      jQuery("#t_"+subgrid_table_id).height(25).hide().filterGrid(""+subgrid_table_id,{gridModel:true,gridToolbar:true});
    },
    subGridRowColapsed: function(subgrid_id, row_id) {},
    JAVASCRIPT
  end

  def sub_grid_inline_edit
    puts self.inspect
    if sub_grid[:inline_edit] == true
      sub_grid[:edit] = "false"
      <<-JAVASCRIPT
          onSelectRow: function(id){
            if(id && id!==lastsel){
              jQuery('#'+subgrid_table_id).restoreRow(lastsel);
              jQuery('#'+subgrid_table_id).editRow(id,true);
              lastsel=id;
            }
          },
      JAVASCRIPT
    else
      ''
    end
  end

  def sub_grid_multiselect
    if sub_grid[:multi_selection]
      'multiselect: true'
    end
  end

  def sub_grid_direct_selection
    if sub_grid[:direct_selection] && sub_grid[:selection_handler].present?
      <<-JAVASCRIPT
          onSelectRow: function(id){
            if(id){
              #{sub_grid[:selection_handler]}(id);
            }
          },
      JAVASCRIPT
    end
  end
end