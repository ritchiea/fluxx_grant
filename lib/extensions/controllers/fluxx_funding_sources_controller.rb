module FluxxFundingSourcesController
  ICON_STYLE = 'style-admin-cards'
  def self.included(base)
    base.insta_index FundingSource do |insta|
      insta.template = 'funding_source_list'
      insta.filter_title = "FundingSources Filter"
      insta.filter_template = 'funding_sources/funding_source_filter'
      insta.order_clause = 'name asc'
      insta.icon_style = ICON_STYLE
      insta.create_link_title = "New Funding Source"
      insta.search_conditions = (lambda do |params, controller_dsl, controller|
        if params[:funding_source] && params[:funding_source][:not_retired]
          '(funding_sources.retired is null or funding_sources.retired = 0)'
        end
      end)
      insta.template_map = {:admin => 'funding_sources_list_admin'}
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
    base.insta_show FundingSource do |insta|
      insta.template = 'funding_source_show'
      insta.icon_style = ICON_STYLE
      insta.add_workflow
    end
    base.insta_new FundingSource do |insta|
      insta.template = 'funding_source_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_edit FundingSource do |insta|
      insta.template = 'funding_source_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_post FundingSource do |insta|
      insta.template = 'funding_source_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_put FundingSource do |insta|
      insta.template = 'funding_source_form'
      insta.icon_style = ICON_STYLE
      insta.add_workflow
    end
    base.insta_delete FundingSource do |insta|
      insta.template = 'funding_source_form'
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