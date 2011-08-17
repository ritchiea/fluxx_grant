module FluxxRequestAmendment
  extend FluxxModuleHelper

  when_included do
    belongs_to :request, :polymorphic => true
    
    insta_utc do |insta|
      insta.time_attributes = [:start_date, :end_date]
    end
    
    insta_filter_amount do |insta|
      insta.amount_attributes = [:amount_recommended]
    end
  end

  class_methods do
  end

  instance_methods do
  end
end
