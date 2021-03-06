module FluxxInitiativesController
  ICON_STYLE = 'style-admin-cards'
  DETAIL_WIDTH = 740
  def self.included(base)
    base.insta_index Initiative do |insta|
      insta.template = 'initiative_list'
      insta.filter_title = "Filter"
      insta.filter_template = 'initiatives/initiative_filter'
      insta.order_clause = 'initiatives.name asc'
      insta.create_link_title = "New Initiative"
      insta.joins = [:sub_program => :program]
      insta.search_conditions = (lambda do |params, controller_dsl, controller|
        if params[:initiative] && params[:initiative][:not_retired]
          '(initiatives.retired is null or initiatives.retired = 0)'
        end
      end)
      insta.icon_style = ICON_STYLE
      insta.detail_width = DETAIL_WIDTH
      insta.template_map = {:admin => 'initiative_list_admin'}
      insta.format do |format|
        format.html do |triple|
          controller_dsl, outcome, default_block = triple
          if params[:admin]
            @suppress_model_iteration = true
          else
            @suppress_model_iteration = false
          end
          default_block.call
        end
      end
    end
    base.insta_show Initiative do |insta|
      insta.template = 'initiative_show'
      insta.footer_template = 'admin_cards/admin_footer'
      insta.icon_style = ICON_STYLE
      insta.detail_width = DETAIL_WIDTH
    end
    base.insta_new Initiative do |insta|
      insta.template = 'initiative_form'
      insta.icon_style = ICON_STYLE
      insta.detail_width = DETAIL_WIDTH
    end
    base.insta_edit Initiative do |insta|
      insta.template = 'initiative_form'
      insta.icon_style = ICON_STYLE
      insta.detail_width = DETAIL_WIDTH
    end
    base.insta_post Initiative do |insta|
      insta.template = 'initiative_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_put Initiative do |insta|
      insta.template = 'initiative_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_delete Initiative do |insta|
      insta.template = 'initiative_form'
      insta.icon_style = ICON_STYLE
    end
    
    base.extend(ModelClassMethods)
    base.class_eval do
      include ModelInstanceMethods
    end
  end

  module ModelClassMethods
  end

  module ModelInstanceMethods
  end
end