module JqgridHelper
  FILTER_OPERATORS = {
    'eq' => " = ",
    'ne' => " <> ",
    'lt' => " < ",
    'le' => " <= ",
    'gt' => " > ",
    'ge' => " >= ",
    'bw' => " LIKE ",
    'bn' => " NOT LIKE ",
    'in' => " IN ",
    'ni' => " NOT IN ",
    'ew' => " LIKE ",
    'en' => " NOT LIKE ",
    'cn' => " LIKE " ,
    'nc' => " NOT LIKE "
  }

  def json_filters(model, filters)
    return unless filters
    options = ActiveSupport::JSON.decode filters
    if options.is_a? Hash
      group_operator = options['groupOp']
      rules = options['rules']
      conditions = []
      rules.each do |key, value|
        field = key['field']
        operator = key['op']
        value = key['data']

        if value and operator
          case operator
          when 'in'
          when 'ni'
            conditions <<  " #{field} #{FILTER_OPERATORS[operator]} (#{prepare_data_value model, field, operator, value}) "
            break
          else
            conditions << " #{field} #{FILTER_OPERATORS[operator]} #{prepare_data_value model, field, operator, value} "
          end
        end

      end
    end
    conditions.join group_operator if conditions
  end

  def prepare_data_value(model, field, operator, value)
    column = model.columns.find {|a| a.name == field}
    case column.type
    when :string, :text
      case operator
      when 'bw', 'bn'
        "'#{value}%'"
      when 'ew', 'en'
        "'%#{value}'"
      when 'cn', 'nc'
        "'%#{value}%'"
      when 'eq', 'ne'
        "'#{value}'"
      else nil
      end
    when :boolean
      "#{value == 'true' ? 'TRUE' : 'FALSE'}"
    when :integer
      value.to_i
    when :float
      value.to_f
    else
      nil
    end
  end

  def jqgrid_stylesheets
    css = capture { stylesheet_link_tag 'jqgrid/jquery-ui-1.7.1.custom'}
    css << capture { stylesheet_link_tag 'jqgrid/ui.jqgrid' }
  end

  def jqgrid_javascripts
    js = capture { javascript_include_tag 'jqgrid/jquery.jqGrid.min' }
  end

  def permissionable_object(params)
    return nil unless (params[:permissionable_id].to_i > 0) and params[:permissionable_type]
    params[:permissionable].strip.classify.constantize.find params[:permissionable_id] rescue nil
  end

  def collection_to_jqgrid(options)
    options[:collection].to_jqgrid_json(options[:columns], params[:page] || 1, params[:rows] || DEFAULT_PER_PAGE, options[:collection].total_entries)
  end

  def set_conditions(model)
    if params[:filters]
      json_filters(model, params[:filters])
    else
      search_params = params.select {|k,v| model.column_names.include? k}
      conditions = []
      search_params.each {|field, value| conditions << " #{field} #{FILTER_OPERATORS['cn']} #{prepare_data_value model, field, 'cn', value} "}
      conditions.join(' AND ')
    end
  end

  def post_data
    if params[:oper] == "del"
      destroy
    elsif params[:oper] == "add"
      create
    else
      update
    end
  end

  def jqgrid(title, id , action, columns = {}, options = {})
    dg =DataGrid.new title, id , action, columns, options
    dg.set_master_options(options, id) if options[:set_master_options]
    dg.set_subgrid_options(options, id) if options[:set_subgrid_options]
    dg.generate_grid
  end
end

private

module JqGrid
  def generate_grid
    <<-JAVASCRIPT
    <script type="text/javascript">
      var lastsel;
      jQuery(document).ready(function()
        {
        jQuery("##{grid[:id]}").jqGrid(
          {
          altRows: #{grid[:alternate_row_shading]},
          caption: "#{grid[:title]}",
          colNames: #{grid[:column_names]},
          colModel: #{grid[:column_model]},
          datatype: "json",
          editurl:'#{grid[:edit_url]}',
          height: '#{grid[:height]}',
          imgpath: 'images/jqgrid',
          multiselect: #{grid[:multi_select]},
          pager: jQuery('##{grid[:id]}_pager'),
          rownumbers: #{grid[:row_numbers]},
          rowNum: #{grid[:rows_per_page]},
          rowList: [10,25,50,100],
          scroll: false,
          search: #{grid[:search]},
          sortname: '#{grid[:sort_column]}',
          sortorder: '#{grid[:sort_order]}',
          subGrid: #{grid[:sub_grid_enabled]},
          shinkToFit: #{grid[:shrink_to_fit]},
          toolbar : [true,"top"],
          // adding ?nd='+new Date().getTime() prevent IE caching
          url: '#{grid[:action]}?nd='+new Date().getTime(),
          viewrecords: true,
          viewsortcols: #{grid[:view_sort_columns]},
          width: #{grid[:width]},
          #{"multiselect: true," if grid[:multi_selection]}
          #{master_details}
          #{grid_loaded}
          #{direct_link(grid)}
          #{editable}
          #{generate_sub_grid}
        });
      #{multihandler}
      #{selection_link}

    jQuery("##{grid[:id]}").navGrid('##{grid[:id]}_pager',
      {edit:#{grid[:edit_button]},add:#{grid[:add]},del:#{grid[:delete]},search:true,refresh:true},
        {},
        {},
        {},
        {multipleSearch:true},
        {afterSubmit:function(r,data){return #{grid[:error_handler_return_value]}(r,data,'edit');}},
        {afterSubmit:function(r,data){return #{grid[:error_handler_return_value]}(r,data,'add');}},
        {afterSubmit:function(r,data){return #{grid[:error_handler_return_value]}(r,data,'delete');}
      })
      #{add_search_toolbar}
      #{add_clear_search_tool}
      jQuery("##{grid[:id]}").filterToolbar();
    });
    </script>
    <table id="#{grid[:id]}" class="scroll" cellpadding="0" cellspacing="0"></table>
    <div id="#{grid[:id]}_pager" class="scroll" style="text-align:center;"></div>
    JAVASCRIPT
  end

  def parse_column_options(columns)
    col_names = "[" # Labels
    col_model = "[" # Options
    columns.each do |column|
      col_names << "'#{column[:label]}',"
      col_model << "{name:'#{column[:field]}', index:'#{column[:field]}'#{get_attributes(column)}},"
    end
    col_names.chop! << "]"
    col_model.chop! << "]"
    [col_names, col_model]
  end

  # Generate a list of attributes for related column (align:'right', sortable:true, resizable:false, ...)
  def get_attributes(column)
    options = ","
    column.except(:field, :label).each do |couple|
      if couple[0] == :editoptions
        options << "editoptions:#{get_edit_options(couple[1])},"
      else
        if couple[1].class == String
          options << "#{couple[0]}:'#{couple[1]}',"
        else
          options << "#{couple[0]}:#{couple[1]},"
        end
      end
    end
    options.chop!
  end

  # Generate options for editable fields (value, data, width, maxvalue, cols, rows, ...)
  def get_edit_options(editoptions)
    options = "{"
    editoptions.each do |couple|
      if couple[0] == :value # :value => [[1, "Rails"], [2, "Ruby"], [3, "jQuery"]]
        options << %Q/value:"/
        couple[1].each do |v|
          options << "#{v[0]}:#{v[1]};"
        end
        options.chop! << %Q/",/
      elsif couple[0] == :data # :data => [Category.all, :id, :title])
        options << %Q/value:"/
        couple[1].first.each do |v|
          options << "#{v[couple[1].second]}:#{v[couple[1].third]};"
        end
        options.chop! << %Q/",/
      else # :size => 30, :rows => 5, :maxlength => 20, ...
        options << %Q/#{couple[0]}:"#{couple[1]}",/
      end
    end
    options.chop! << "}"
  end

  def add_clear_search_tool
    <<-JAVASCRIPT
      .navButtonAdd("##{grid[:id]}_pager",
        {caption:"",title:"Clear Search",buttonicon :'ui-icon-refresh',
          onClickButton:function(){
            jQuery("##{grid[:id]}")[0].clearToolbar()
          }
        })
    JAVASCRIPT
  end

  def add_search_toolbar
    <<-JAVASCRIPT
      .navButtonAdd("##{grid[:id]}_pager",
        {caption:"",title:"Toggle Search Toolbar", buttonicon :'ui-icon-pin-s',
          onClickButton:function(){
            jQuery("##{grid[:id]}")[0].toggleToolbar()
          }
        })
    JAVASCRIPT
  end

  # Enable direct selection (when a row in the table is clicked)
  # The javascript function created by the user (options[:selection_handler]) will be called with the selected row id as a parameter
  def direct_link(grid)
    if grid[:direct_selection] && grid[:selection_handler] && grid[:multi_selection].blank?
      <<-JAVASCRIPT
        onSelectRow: function(id){
          if(id){
            #{grid[:selection_handler]}(id);
          }
        }
      JAVASCRIPT
    else
      ''
    end
  end

  def examples
    return
    # get grid data from selected row
    <<-JAVASCRIPT
      jQuery("#a1").click( function(){
        var id = jQuery("#list5").getGridParam('selrow');
        if (id)	{
          var ret = jQuery("#list5").getRowData(id);
          alert("id="+ret.id+" invdate="+ret.invdate+"...");
        } else {
          alert("Please select row");
        }
      });
    JAVASCRIPT

    # delete specific row in table
    <<-JAVASCRIPT
      jQuery("#a2").click( function(){
        var su=jQuery("#list5").delRowData(12);
        if(su) {
          alert("Success. Write custom code to delete row from server"); else alert("Already deleted or not in list");
      });
    JAVASCRIPT

    # update specific row in table
    <<-JAVASCRIPT
      jQuery("#a3").click( function(){
        var su=jQuery("#list5").setRowData(11,{amount:"333.00",tax:"33.00",total:"366.00",note:"<img src='images/user1.gif'/>"});
        if(su) {
          alert("Succes. Write custom code to update row in server");
        } else {
           alert("Can not update")
        }
      });
    JAVASCRIPT

    # insert row in table
    <<-JAVASCRIPT
      jQuery("#a4").click( function(){
        var datarow = {id:"99",invdate:"2007-09-01",name:"test3",note:"note3",amount:"400.00",tax:"30.00",total:"430.00"};
        var su=jQuery("#list5").addRowData(99,datarow);
        if(su) {
          alert("Succes. Write custom code to add data in server")
        } else {
          alert("Can not update")
        }
    });
    JAVASCRIPT
  end
end

module JqGridMaster
  def master_grid_details
    <<-JAVASCRIPT
      onSelectRow: function(ids)
        {
        if(ids == null)
          {
          ids=0;
          if(jQuery("##{grid[:id]}_details").getGridParam('records') >0)
            {
            jQuery("##{grid[:id]}_details").setGridParam({url:"#{master_details[:url]}?q=1&id="+ids,page:1})
              .setCaption("#{[:details_caption]}: "+ids)
              .trigger('reloadGrid');
            }
          } else
            {
              jQuery("##{grid[:id]}_details").setGridParam({url:"#{master_details[:url]}?q=1&id="+ids,page:1})
              .setCaption("#{master_details[:caption]} : "+ids)
              .trigger('reloadGrid');
            }
        },
    JAVASCRIPT
  end

  # Enable inline editing
  # When a row is selected, all fields are transformed to input types
  def editable
    if grid[:edit] && grid[:inline_edit] == "true"
      <<-JAVASCRIPT
        onSelectRow: function(id){
          if(id && id!==lastsel){
            jQuery('##{grid[:id]}').restoreRow(lastsel);
            jQuery('##{grid[:id]}').editRow(id, true, #{grid[:inline_edit_handler]}, #{grid[:error_handler]});
            lastsel=id;
          }
        }
      JAVASCRIPT
    end
  end

  # Enable grid_loaded callback
  # When data are loaded into the grid, call the Javascript function options[:grid_loaded] (defined by the user)
  def grid_loaded
    if grid[:grid_loaded]
      <<-JAVASCRIPT
        loadComplete: function(){
          #{grid[:grid_loaded]}();
        }
      JAVASCRIPT
    end
  end

  #If set to true, an additional column is added on the left side of the grid. This adds 28px to the grid's width.
  #When the grid is constructed the content of this column is filled with a check box element. When we select a row
  #the check box's state becomes checked (unless multiboxonly has been set to true, the row can be clicked anywhere
  #on the row, not just in the checkbox). When we select another row the previous row does not change its state.
  #When we click on a row that is selected, the state becomes unchecked and the row is unselected. (If onRightClickRow
  #has been defined, then right-clicking a row does not select the row).
  def multiselect
    "multiselect: true,"
  end

  def multihandler
    <<-JAVASCRIPT
    jQuery("##{grid[:id]}_select_button").click( function()
      {
      var s; s = jQuery("##{grid[:id]}").getGridParam('selarrrow');
      #{grid[:selection_handler]}(s);
      return false;
      });
    JAVASCRIPT
  end

  # Enable selection link, button
  # The javascript function created by the user (options[:selection_handler]) will be called with the selected row id as a parameter
  def selection_link
    if (grid[:direct_selection].blank? || grid[:direct_selection] == false) && grid[:selection_handler].present? && (grid[:multi_selection].blank? || grid[:multi_selection] == false)
      <<-JAVASCRIPT
        jQuery("##{grid[:id]}_select_button").click( function()
          {
          var id = jQuery("##{grid[:id]}").getGridParam('selrow');
          if (id) {
            #{grid[:selection_handler]}(id);
            } else {
            alert("Please select a row");
            }
            return false;
          });
      JAVASCRIPT
    end
  end
end

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

class DataGrid
  include JqGrid
  include JqGridMaster
  include JqGridSubGrid
  attr_accessor :grid, :master_details, :sub_grid

  def initialize(title, id , action, columns, options)
    @grid = {}
    @grid[:action] = action
    @grid[:alternate_row_shading] = options[:alternate_row_shading].blank? ? 'true' : 'true'
    @grid[:add] = options[:add].blank? ? 'false' : options[:add].to_s
    @grid[:column_names], @grid[:column_model] = parse_column_options(columns)
    @grid[:delete] = options[:delete].blank? ? 'false' : options[:delete].to_s
    @grid[:edit_button] = options[:edit] == true and options[:inline_edit] == 'false' ? 'true' : 'false'
    if options[:error_handler].blank?
      @grid[:error_handler] = 'null'
      @grid[:error_handler_return_value] = 'true;'
    else
      @grid[:error_handler] = options[:error_handler]
      @grid[:error_handler_return_value] = @error_handler
    end
    @grid[:error_handler_return_value] = @error_handler
    @grid[:edit_url] = options[:edit_url]
    @grid[:height] = options[:height].blank? ? '100%' : options[:height]
    @grid[:id] = id
    @grid[:inline_edit_handler] = options[:inline_edit_handler].blank? ? 'null': options[:inline_edit_handler]
    @grid[:inline_edit] = options[:inline_edit].blank? ? 'false' : options[:inline_edit].to_s
    @grid[:multi_select] = options[:multi_select].blank? ? 'false' : 'true'
    @grid[:row_list] = options[:row_list].blank? ? '[10,25,50,100]' : options[:row_list]
    @grid[:row_numbers] = options[:row_numbers].blank? ? 'false' : 'true'
    @grid[:rows_per_page] = options[:rows_per_page].blank? ? '10' : options[:rows_per_page]
    @grid[:search] = options[:search].blank? ? 'false' : 'true'
    @grid[:shrink_to_fit] = options[:shrink_to_fit].blank? ? 'false' : 'true'
    @grid[:sort_column] = options[:sort_column].blank? ? 'id' : options[:sort_column]
    @grid[:sort_order] = options[:sort_order].blank? ? 'ASC' : options[:sort_order]
    @grid[:sub_grid_enabled] = options[:subgrid].blank? ? 'false' : 'true'
    @grid[:title] = title
    @grid[:view_sort_columns] = options[:view_sort_columns].blank? ? "[false,'vertical',true]" : options[:view_sort_columns]
    @grid[:width] = options[:width].blank? ? '800' : options[:width]


    @master_grid = {}


    @sub_grid = {}
    @sub_grid[:add] = (options[:subgrid][:add].blank?) ? 'false' : 'true'
    @sub_grid[:alternate_row_shading] = options[:alternate_row_shading].blank? ? 'false' : 'true'
    @sub_grid[:column_names], @sub_grid[:column_model] = parse_column_options(options[:subgrid][:columns])
    @sub_grid[:delete] = (options[:subgrid][:delete].blank?) ? 'false' : 'true'
    @sub_grid[:edit] = (options[:subgrid][:edit].blank?) ? 'false' : 'true'
    @sub_grid[:edit_url] = options[:subgrid][:edit_url]
    @sub_grid[:height] = options[:subgrid][:height].blank? ? '100%' : options[:height]
    @sub_grid[:multi_select] = options[:subgrid][:multi_select].blank? ? 'false' : 'true'
    @sub_grid[:refresh] = (options[:subgrid][:refresh].blank?) ? 'false' : 'true'
    @sub_grid[:rows_per_page] = "10" if options[:subgrid][:rows_per_page].blank?
    @sub_grid[:sort_column] = "id" if options[:subgrid][:sort_column].blank?
    @sub_grid[:sort_order] = "asc" if options[:subgrid][:sort_order].blank?
    @sub_grid[:subgrid_search] = (options[:subgrid][:search].blank?) ? 'false' : 'true'
    @sub_grid[:url] = options[:subgrid][:url]
  end
end

module JqgridJson
  def to_jqgrid_json(attributes, current_page, per_page, total)
    json = %Q({"page":"#{current_page}","total":#{total/per_page.to_i+1},"records":"#{total}","rows":[)

    each do |elem|
      json << %Q({"id":"#{elem.id}","cell":[)
      couples = elem.attributes.symbolize_keys
      attributes.each do |atr|
        value = couples[atr]
        association = atr.to_s.split('.')
        case association.length
        when 1
          value = elem.send(association[0].to_sym) if elem.respond_to?(atr) && value.blank?
        when 2
          value = elem.send(association[0].to_sym).andand.send(association[1].to_sym) if association[0] && value.blank?
        when 3
          value = elem.send(association[0].to_sym).send(association[1].to_sym).send(association[2].to_sym) if association[0] && association[1] && value.blank?
        end
        json << %Q("#{value}",)
      end
      json.chop! << "]},"
    end
    json.chop! << "]}"
  end

end

class Array
  include JqgridJson
end