module FluxxRequestEvaluationMetric
  SEARCH_ATTRIBUTES = [:request_id]

  def self.included(base)
    base.belongs_to :request
    base.validates_presence_of :description
    
    base.insta_search do |insta|
      insta.filter_fields = SEARCH_ATTRIBUTES
    end
    base.insta_export
    base.insta_multi
    base.insta_lock
    base.insta_realtime
    
    base.insta_template do |insta|
      insta.entity_name = 'request_evaluation_metric'
      insta.add_methods [:description, :comment]
      insta.remove_methods [:id]
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
      (user.primary_organization.id == self.request.program_organization_id) || (user.primary_organization.id == self.request.fiscal_organization_id)
    end
  end
end