module FluxxRequestReviewerAssignment
  extend FluxxModuleHelper

  SEARCH_ATTRIBUTES = [:created_at, :updated_at, :id]
  
  when_included do
    belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
    belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'
    belongs_to :user
    belongs_to :request

    acts_as_audited({:full_model_enabled => false, :except => [:created_by_id, :updated_by_id, :delta, :updated_by, :created_by, :audits]})

    insta_search do |insta|
      insta.filter_fields = SEARCH_ATTRIBUTES
      insta.derived_filters = {}
    end

    insta_realtime do |insta|
      insta.delta_attributes = SEARCH_ATTRIBUTES
      insta.updated_by_field = :updated_by_id
    end
    insta_json do |insta|
      # insta.add_method 'primary_org_name'
      # insta.copy_style :simple, :detailed
      # insta.add_method 'related_organizations', :detailed
    end
    
    insta_multi
    insta_export do |insta|
      insta.filename = 'request_reviewer_assignment'
      insta.headers = [['Date Created', :date], ['Date Updated', :date]]
      insta.sql_query = "created_at, updated_at
                from request_reviewer_assignments
                where id IN (?)"
    end
    insta_lock

    insta_template do |insta|
      insta.entity_name = 'request_reviewer_assignment'
      insta.add_methods []
      insta.remove_methods [:id]
    end

    insta_favorite
    insta_utc do |insta|
      insta.time_attributes = [] 
    end
    insta_filter_amount do |insta|
      insta.amount_attributes = []
    end
  end

  class_methods do
  end
end