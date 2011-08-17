module FluxxBudgetRequest
  SEARCH_ATTRIBUTES = [:created_at, :updated_at, :id, :request_id]
  LIQUID_METHODS = [:name, :amount_requested, :amount_recommended ]  
  
  def self.included(base)
    base.belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
    base.belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'
    base.belongs_to :request

    base.validates_presence_of :name

    base.acts_as_audited({:full_model_enabled => false, :except => [:created_by_id, :updated_by_id, :delta, :updated_by, :created_by, :audits]})

    base.insta_search do |insta|
      insta.filter_fields = SEARCH_ATTRIBUTES
      insta.derived_filters = {}
    end

    base.insta_realtime do |insta|
      insta.delta_attributes = SEARCH_ATTRIBUTES
      insta.updated_by_field = :updated_by_id
    end
    base.insta_multi
    base.insta_export do |insta|
      insta.filename = 'budget_request'
      insta.headers = [['Date Created', :date], ['Date Updated', :date]]
      insta.sql_query = "created_at, updated_at
                from budget_requests
                where id IN (?)"
    end
    base.insta_lock

    base.insta_template do |insta|
      insta.entity_name = 'budget_request'
      insta.add_methods []
      insta.remove_methods [:id]
    end
    base.liquid_methods *( LIQUID_METHODS )    

    base.insta_favorite
    base.insta_utc do |insta|
      insta.time_attributes = [] 
    end
    base.insta_filter_amount do |insta|
      insta.amount_attributes = [:amount_requested, :amount_recommended]
    end
    
    base.extend(ModelClassMethods)
    base.class_eval do
      include ModelInstanceMethods
    end
  end

  module ModelClassMethods
  end
  
  module ModelInstanceMethods
    def relates_to_user? user
      (user.id == self.created_by_id)
    end
  end
end