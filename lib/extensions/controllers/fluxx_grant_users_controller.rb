# Supplements FluxxUsersController in fluxx_crm
module FluxxGrantUsersController
  def self.included(base)
    base.send :include, FluxxUsersController
    base.insta_index User do |insta|
      insta.filter_title = "People Filter"
      insta.filter_template = 'users/user_filter'
    end
    
    base.insta_related User do |insta|
      insta.add_related do |related|
        related.display_name = 'Requests'
        related.show_tab? do |args|
          controller, model = args
          controller.current_user.has_view_for_model?(Request) && !controller.current_user.is_board_member?
        end
        related.for_search do |model|
          model.related_requests
        end
        related.add_title_block do |model|
          model.title if model
        end
        related.display_template = '/grant_requests/related_request'
      end
      insta.add_related do |related|
        related.display_name = 'Grants'
        related.show_tab? do |args|
          controller, model = args
          controller.current_user.has_view_for_model? Request
        end
        related.for_search do |model|
          model.related_grants
        end
        related.add_title_block do |model|
          model.title if model
        end
        related.display_template = '/grant_requests/related_request'
        related.add_model_url_block do |model|
          send :granted_request_path, :id => model.id
        end
      end
      insta.add_related do |related|
        related.display_name = 'Orgs'
        related.show_tab? do |args|
          controller, model = args
          controller.current_user.has_view_for_model? Organization
        end
        related.for_search do |model|
          model.related_organizations 1000
        end
        related.add_title_block do |model|
          model.name if model
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