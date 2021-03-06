module FluxxProgramsController
  ICON_STYLE = 'style-admin-cards'
  DETAIL_WIDTH = 740
  def self.included(base)
    base.insta_index Program do |insta|
      insta.template = 'program_list'
      insta.filter_title = "Filter"
      insta.filter_template = 'programs/program_filter'
      insta.order_clause = 'name asc'
      insta.create_link_title = "New Program"
      insta.search_conditions = (lambda do |params, controller_dsl, controller|
        if params[:program] && params[:program][:not_retired]
          '(programs.retired is null or programs.retired = 0)'
        end
      end)
      insta.icon_style = ICON_STYLE
      insta.detail_width = DETAIL_WIDTH
      insta.template_map = {:admin => 'program_list_admin'}
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
    base.insta_show Program do |insta|
      insta.template = 'program_show'
      insta.footer_template = 'admin_cards/admin_footer'
      insta.icon_style = ICON_STYLE
      insta.detail_width = DETAIL_WIDTH
    end
    base.insta_new Program do |insta|
      insta.template = 'program_form'
      insta.icon_style = ICON_STYLE
      insta.detail_width = DETAIL_WIDTH
    end
    base.insta_edit Program do |insta|
      insta.template = 'program_form'
      insta.icon_style = ICON_STYLE
      insta.detail_width = DETAIL_WIDTH
    end
    base.insta_post Program do |insta|
      insta.template = 'program_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_put Program do |insta|
      insta.template = 'program_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_delete Program do |insta|
      insta.template = 'program_form'
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