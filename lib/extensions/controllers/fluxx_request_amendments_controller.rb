module FluxxRequestAmendmentsController
  extend FluxxModuleHelper

  ICON_STYLE = 'style-request-amendments'

  when_included do
    insta_index RequestAmendment do |insta|
      insta.search_conditions = {:original => 0}
      insta.template = 'request_amendment_list'
      insta.filter_title = "Amendments Filter"
      insta.filter_template = 'request_amendments/request_amendment_filter'
      insta.order_clause = 'updated_at desc'
      insta.icon_style = ICON_STYLE
    end
    insta_show RequestAmendment do |insta|
      insta.template = 'request_amendment_show'
      insta.icon_style = ICON_STYLE
      insta.add_workflow
      insta.format do |format|
        format.html do |triple|
          controller_dsl, outcome, default_block = triple
          if params[:view_states]
            local_model = instance_variable_get '@model'
            send :fluxx_show_card, controller_dsl, {:template => 'insta/view_states', :footer_template => 'insta/simple_footer'}
          else
           default_block.call
          end
        end
      end
      
    end
    insta_new RequestAmendment do |insta|
      insta.template = 'request_amendment_form'
      insta.icon_style = ICON_STYLE
    end
    insta_edit RequestAmendment do |insta|
      insta.template = 'request_amendment_form'
      insta.icon_style = ICON_STYLE
    end
    insta_post RequestAmendment do |insta|
      insta.template = 'request_amendment_form'
      insta.icon_style = ICON_STYLE
    end
    insta_put RequestAmendment do |insta|
      insta.template = 'request_amendment_form'
      insta.icon_style = ICON_STYLE
      insta.add_workflow
    end
    insta_delete RequestAmendment do |insta|
      insta.template = 'request_amendment_form'
      insta.icon_style = ICON_STYLE
    end
    insta_related RequestAmendment do |insta|
      insta.add_related do |related|
      end
    end
    
    insta_related RequestAmendment do |insta|
      insta.add_related do |related|
        related.display_name = 'Grants'
        related.show_tab? do |args|
          controller, model = args
          controller.current_user.has_view_for_model? RequestAmendment
        end
        related.for_search do |model|
          model.related_grants
        end
        related.add_title_block do |model|
          model.title if model
        end
        related.add_model_url_block do |model|
          send :granted_request_path, :id => model.id
        end
        related.display_template = '/grant_requests/related_request'
      end
    end
    
  end
end