module FluxxGrantRequestsController
  ICON_STYLE = 'style-grant-requests'
  def self.included(base)
    base.send :include, FluxxCommonRequestsController
    base.insta_index Request do |insta|
      insta.search_conditions = {:granted => 0, :has_been_rejected => 0}
      insta.template = 'grant_request_list'
      insta.controller_name = 'Requests'
      insta.filter_title = "Requests Filter"
      insta.filter_template = 'grant_requests/grant_request_filter'
      insta.order_clause = 'updated_at desc'
      insta.include_relation = [:program_lead, :grantee_org_owner, :grantee_signatory, :fiscal_org_owner, :fiscal_signatory, :program_organization, :fiscal_organization, :program]
      
      insta.icon_style = ICON_STYLE
      insta.delta_type = GrantRequestsController.translate_delta_type false # Vary the request type based on whether a request has been granted yet or not
      insta.format do |format|
        format.html do |triple|
          controller_dsl, outcome, default_block = triple
          grant_request_index_format_html controller_dsl, outcome, default_block
        end
      end
      insta.summary_view do |format|
        format.html do |triple|
          controller_dsl, outcome, default_block = triple
          query = "SELECT SUM(r.amount_requested) AS amount, AVG(DATEDIFF(CURDATE(), r.created_at)) as days, AVG(r.amount_requested) AS average, COUNT(r.id) AS count FROM requests r WHERE r.id IN (?)"
          ids=  @models.map(&:id)
          results = ReportUtility.single_value_query([query, ids])
          @grants = false
          @amount_in_pipeline = results["amount"]
          @number_in_pipeline = results["count"]
          @average_amount = results["average"]
          @average_days = results["days"]
          @pipeline = []
          exclude_states = GrantRequest.all_states_with_category :granted
          query = "SELECT sum(r.amount_requested) as amount, count(r.id) as count, r.state AS state FROM requests r WHERE r.id IN (?) and r.state not in (?) group by r.state"
          req = Request.connection.execute(Request.send(:sanitize_sql, [query, ids, exclude_states]))
          max = 0
          i = 0
          dummy_model = Request.new
          req.each_hash do |res|
            amount = res["amount"] ? res["amount"].to_i : 0
            count = res["count"] ? res["count"].to_i : 0
            dummy_model.state = res["state"]
            max = count if count > max
            @pipeline[i] = {:count => count, :amount  => amount, :state => dummy_model.state_to_english}
            i += 1
          end
          max = max.to_f
          @pipeline.each{|stats| stats[:percentage] = (max > 0 ? stats[:count] / max : 1) * 100}

          default_block.call
        end
      end
      insta.spreadsheet_view do |format|
        format.html do |triple|
          controller_dsl, outcome, default_block = triple
          default_block.call
        end
      end

    end
    base.insta_show GrantRequest do |insta|
      insta.force_redirect do |conf|
        # Check to see if this model is a FIP
        model_id = conf.load_param_id params
        model = FipRequest.safe_find(model_id, conf.force_load_deleted_param(params))
        
        if model
          redirect_params = params.delete_if{|k,v| %w[controller action].include?(k) }
          fluxx_redirect (fip_request_path(model.id, redirect_params)), conf
        end
      end
      
      insta.template = 'grant_request_show'
      insta.icon_style = ICON_STYLE
      insta.add_workflow
      insta.format do |format|
        format.html do |triple|
          if @model and @model.granted
            redirect_params = params.delete_if{|k,v| %w[controller action].include?(k) }
            fluxx_redirect granted_request_path(redirect_params)
          else
            controller_dsl, outcome, default_block = triple
            grant_request_show_format_html controller_dsl, outcome, default_block
          end
        end
      end
      insta.post do |triple|
        controller_dsl, model, outcome = triple
        set_enabled_variables controller_dsl
      end
    end
    base.insta_new GrantRequest do |insta|
      insta.template = 'grant_request_form'
      insta.icon_style = ICON_STYLE
      insta.pre_create_model = true
    end
    base.insta_edit GrantRequest do |insta|
      insta.template = 'grant_request_form'
      insta.template_map = { :amend => "grant_request_amend_form" }
      insta.icon_style = ICON_STYLE
      insta.pre_create_model = true
      insta.format do |format|
        format.html do |triple|
          controller_dsl, outcome, default_block = triple
          grant_request_edit_format_html controller_dsl, outcome, default_block
        end
      end
      
    end
    base.insta_post GrantRequest do |insta|
      insta.template = 'grant_request_form'
      insta.icon_style = ICON_STYLE
      insta.pre_create_model = true
    end
    base.insta_put GrantRequest do |insta|
      insta.template = 'grant_request_form'
      insta.template_map = { :amend => "grant_request_amend_form" }
      insta.icon_style = ICON_STYLE
      insta.add_workflow
      insta.pre_create_model = true
      insta.format do |format|
        format.html do |triple|
          controller_dsl, outcome, default_block = triple
          grant_request_update_format_html controller_dsl, outcome, default_block
        end
      end
    end
    base.insta_delete GrantRequest do |insta|
      insta.template = 'grant_request_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_related GrantRequest do |insta|      
      insta.add_related do |related|
        related.display_name = 'People'
        related.add_title_block do |model|
          model.full_name if model
        end
        related.for_search do |model|
          model.related_users
        end
        related.display_template = '/users/related_users'
      end
      insta.add_related do |related|
        related.display_name = 'Orgs'
        related.add_title_block do |model|
          model.name if model
        end
        related.for_search do |model|
          model.related_organizations
        end
        related.display_template = '/organizations/related_organization'
      end
      insta.add_related do |related|
        related.display_name = 'Projects'
        related.add_title_block do |model|
          model.title if model
        end
        related.for_search do |model|
          model.related_projects
        end
        related.display_template = '/projects/related_project'
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
