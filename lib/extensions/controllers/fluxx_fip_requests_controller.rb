module FluxxFipRequestsController
  ICON_STYLE = 'style-fip-requests'
  def self.included(base)
    base.send :include, FluxxCommonRequestsController
    base.insta_index Request do |insta|
      insta.search_conditions = {:granted => 0, :has_been_rejected => 0}
      insta.template = 'grant_requests/grant_request_list'
      insta.filter_title = "Fip Requests Filter"
      insta.filter_template = 'fip_request_filter'
      insta.order_clause = 'updated_at desc'
      insta.icon_style = ICON_STYLE
    end
    base.insta_show FipRequest do |insta|
      insta.template = 'grant_requests/grant_request_show'
      insta.icon_style = ICON_STYLE
      insta.add_workflow
      insta.format do |format|
        format.html do |controller_dsl, controller, outcome, default_block|
          base.grant_request_show_format_html controller_dsl, controller, outcome, default_block
        end
      end
      insta.post do |controller_dsl, controller|
        base.set_enabled_variables controller_dsl, controller
      end
    end
    base.add_grant_request_install_role
    base.insta_new FipRequest do |insta|
      insta.template = 'fip_requests/fip_request_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_edit FipRequest do |insta|
      insta.template = 'fip_requests/fip_request_form'
      insta.icon_style = ICON_STYLE
      # ESH: hmmm this is a bit ugly; look into a way to set the context to be the same as the controller's
      insta.format do |format|
        format.html do |controller_dsl, controller, outcome, default_block|
          base.grant_request_edit_format_html controller_dsl, controller, outcome, default_block
        end
      end
    end
    base.insta_post FipRequest do |insta|
      insta.template = 'fip_requests/fip_request_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_put FipRequest do |insta|
      insta.template = 'fip_requests/fip_request_form'
      insta.icon_style = ICON_STYLE
      insta.add_workflow
      insta.format do |format|
        format.html do |controller_dsl, controller, outcome, default_block|
          base.grant_request_update_format_html controller_dsl, controller, outcome, default_block
        end
      end
    end
    base.insta_delete FipRequest do |insta|
      insta.template = 'fip_requests/fip_request_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_related FipRequest do |insta|
      insta.add_related do |related|
        related.display_name = 'People'
        related.for_search do |model|
          model.related_users
        end
        related.display_template = '/users/related_users'
      end
      insta.add_related do |related|
        related.display_name = 'Orgs'
        related.for_search do |model|
          model.related_organizations
        end
        related.display_template = '/organizations/related_organization'
      end
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