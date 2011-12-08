module FluxxLoisController
  ICON_STYLE = 'style-lois'

  def self.included(base)
    base.skip_before_filter :require_user, :only => [:new, :create]
    
    base.insta_index Loi do |insta|
      insta.template = 'loi_list'
      insta.filter_title = "Lois Filter"
      insta.filter_template = 'lois/loi_filter'
      insta.order_clause = 'updated_at desc'
      insta.icon_style = ICON_STYLE
    end
    base.insta_show Loi do |insta|
      insta.template = 'loi_show'
      insta.icon_style = ICON_STYLE
      insta.add_workflow
      insta.template_map = {:matching_users => "matching_users_list", :matching_organizations => "matching_organizations_list"}
      insta.footer_template =  'loi_footer'
    end
    base.insta_edit Loi do |insta|
      insta.icon_style = ICON_STYLE
      insta.template = 'loi_form'
      insta.template_map = {:connect_organization =>  "connect_organization", :connect_user => "connect_user"}
    end
    base.insta_post Loi do |insta|
      insta.template = 'loi_form'
      insta.icon_style = ICON_STYLE
    end
    base.insta_put Loi do |insta|
      insta.template = 'loi_form'
      insta.template_map = {:connect_organization =>  "connect_organization", :connect_user => "connect_user"}
      insta.icon_style = ICON_STYLE
      insta.add_workflow
      insta.pre do |triple|
        if params[:user]
          params.delete(:loi)
          params[:connect_user] = true
          @user = User.new(params[:user])
          @user.save
        end
        if params[:organization]
          params.delete(:loi)
          params[:connect_organization] = true
          @organization = Organization.new(params[:organization])
          @organization.save
        end
      end
      insta.post do |triple|
        controller_dsl, model, outcome = triple
        if (params[:link_user].to_i > 0)
          @user = User.find(params[:link_user].to_i)
        end
        if (params[:link_organization].to_i > 0)
          @organization = Organization.find(params[:link_organization].to_i)
        end

        model.link_user @user if @user
        model.link_organization @organization if @organization

        if params[:disconnect_user]
          model.update_attribute "user_id", nil
        end
        if params[:disconnect_organization]
          model.update_attribute "organization_id", nil
        end
        if params[:promote_to_request] && model.user && model.organization && !model.request
          request = GrantRequest.new(:program_organization_id => model.organization_id, :program_id => model.program_id,
                                :amount_requested => model.amount_requested, :duration_in_months => model.duration_in_months,
                                :grant_begins_at => model.grant_begins_at, :project_summary => model.project_summary, :grantee_org_owner_id => model.user_id)
          request.grant_type = model.grant_type if request.respond_to?(:grant_type) && model.respond_to?(:grant_type)
          draft_state = Request.all_states_with_category("draft").first
          request.state = draft_state if draft_state

          if request.save(:validate => false)
            request_attributes = request.all_dynamic_attributes
            model.all_dynamic_attributes.each do |k,v|
              request.send(k, model.send(k)) if request_attributes[k]
            end
            request.project_title = model.project_title if model.respond_to? :project_title
            request.save(:validate => false)
            model.update_attribute :request_id, request.id
          else
            flash[:error] = I18n.t(:unable_to_promote) + request.errors.full_messages.to_sentence + '.'
          end
        end
      end
      insta.format do |format|
        format.html do |triple|
          controller_dsl, outcome, default_block = triple
          if (params[:user] && !@user.errors.empty?) || (params[:organization] && !@organization.errors.empty?)
            response.headers['fluxx_result_failure'] = 'update'
            flash[:error] = t(:errors_were_found) unless flash[:error]
            flash[:info] = nil
            send :fluxx_edit_card, controller_dsl
          else
            default_block.call
          end
        end
      end

    end
    base.insta_delete Loi do |insta|
      insta.template = 'loi_form'
      insta.icon_style = ICON_STYLE
    end
    
    base.insta_new Loi do |insta|
      insta.layout = "portal"
      insta.icon_style = ICON_STYLE
      insta.template = 'lois/loi_new'
      insta.pre_create_model = false
      insta.skip_permission_check = true
    end

    base.insta_post GrantRequest do |insta|
      insta.view = 'lois/new'
      insta.icon_style = ICON_STYLE
      insta.pre_create_model = true
      insta.skip_permission_check = true
      insta.format do |format|
        format.html do |triple|
          controller_dsl, outcome, default_block = triple
          response.headers['fluxx_template'] = 'loi'
        end
      end
    end
    
    base.insta_related Loi do |insta|
      insta.add_related do |related|
        related.display_name = 'Person'
        related.for_search do |model|
          [model.user]
        end
        related.add_title_block do |model|
          model.full_name if model
        end
        related.display_template = '/users/related_users'
      end
      insta.add_related do |related|
        related.display_name = 'Org'
        related.for_search do |model|
          [model.organization]
        end
        related.add_title_block do |model|
          model.name if model
        end
        related.display_template = '/organizations/related_organization'
      end
      insta.add_related do |related|
        related.display_name = 'Request'
        related.for_search do |model|
          [model.request]
        end
        related.add_title_block do |model|
          model.title if model
        end
        related.display_template = '/grant_requests/related_request'
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