module FluxxRequestReview
  SEARCH_ATTRIBUTES = [:grant_program_ids, :grant_sub_program_ids, :conflict_reported, :created_at, :id, :updated_at, :request_hierarchy, :allocation_hierarchy, :model_theme_id]
  
  def self.included(base)
    base.belongs_to :request
    base.belongs_to :grant, :class_name => 'GrantRequest', :foreign_key => 'request_id', :conditions => {:granted => true}

    base.belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
    base.belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'

    base.acts_as_audited({:full_model_enabled => false, :except => [:created_by_id, :updated_by_id, :delta, :updated_by, :created_by, :audits]})

    base.insta_search do |insta|
      insta.filter_fields = SEARCH_ATTRIBUTES
      insta.derived_filters = {
        :request_hierarchy => (lambda do |search_with_attributes, request_params, name, val|
          FluxxGrantSphinxHelper.prepare_hierarchy search_with_attributes, name, val
        end),
      }
    end

    base.insta_realtime do |insta|
      insta.delta_attributes = SEARCH_ATTRIBUTES
      insta.updated_by_field = :updated_by_id
    end
    base.insta_multi
    base.insta_export do |insta|
      insta.filename = 'request_review'
      insta.headers = [['Date Created', :date], ['Date Updated', :date], 'Reviewer', 'Program', 'Sub Program', 'Request ID', 'Rating']
      insta.sql_query = "request_reviews.created_at, request_reviews.updated_at,  CONCAT(users.first_name, ' ', users.last_name), programs.name, sub_programs.name, requests.base_request_id, request_reviews.rating
                from request_reviews
                left join requests on requests.id = request_reviews.request_id
                left join users on users.id = request_reviews.created_by_id
                left join programs on programs.id = requests.program_id
                left join sub_programs on sub_programs.id = requests.sub_program_id
                where request_reviews.id IN (?)"
    end
    base.insta_lock

    base.insta_template do |insta|
      insta.entity_name = 'request_review'
      insta.add_methods []
      insta.remove_methods [:id]
    end

    base.insta_favorite
    base.insta_utc do |insta|
      insta.time_attributes = [] 
    end
    
#    base.insta_workflow do |insta|
#      # insta.add_state_to_english :new, 'New Request'
#      # insta.add_event_to_english :recommend_funding, 'Recommend Funding'
#    end
    base.insta_formbuilder do |insta|
    end
    
    base.extend(ModelClassMethods)
    base.class_eval do
      include ModelInstanceMethods
    end
    
    base.add_sphinx if base.respond_to?(:sphinx_indexes) && !(base.connection.adapter_name =~ /SQLite/i)
  end
  

  module ModelClassMethods
    def add_sphinx
      include_model_theme_id = self.column_names.include?('model_theme_id')

      define_index :request_review_first do

        # fields
        indexes request.program_organization.name, :as => :request_org_name, :sortable => true
        indexes request.program_organization.acronym, :as => :request_org_acronym, :sortable => true
        indexes "CONCAT(IF(requests.type = 'FipRequest', 'F-', 'R-'),requests.base_request_id)", :as => :request_id, :sortable => true
        indexes "lower(TRIM(CONCAT(CONCAT(IFNULL(users.first_name, ' '), ' '), IFNULL(users.last_name, ' '))))", :as => :external_reviewer, :sortable => true

        # attributes
        has created_at, updated_at, deleted_at, created_by_id, conflict_reported
        has created_by(:id), :as => :created_by_ids
        has grant(:id), :as => :grant_ids
        set_property :delta => :delayed
        has FluxxGrantSphinxHelper.request_hierarchy, :type => :multi, :as => :request_hierarchy
        has model_theme_id if include_model_theme_id
      end
    end
  end
  
  module ModelInstanceMethods
    def relates_to_user? user
      (user.id == self.created_by_id)
    end
  end
end