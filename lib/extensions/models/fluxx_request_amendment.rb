module FluxxRequestAmendment
  SEARCH_ATTRIBUTES = [:created_at, :updated_at, :duration, :start_date, :end_date, :original, :request_id, :filter_state, :request_type, :amount_recommended, :request_hierarchy, :lead_user_ids]

  extend FluxxModuleHelper

  when_included do
    belongs_to :request
    belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
    belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'
    has_many :notes, :as => :notable, :conditions => {:deleted_at => nil}
    has_many :workflow_events, :as => :workflowable
    acts_as_audited({:full_model_enabled => false, :except => [:created_by_id, :modified_by_id, :locked_until, :locked_by_id, :delta, :updated_by, :created_by, :audits]})
    
    insta_utc do |insta|
      insta.time_attributes = [:start_date, :end_date]
    end
    
    insta_search do |insta|
      insta.filter_fields = SEARCH_ATTRIBUTES
      insta.derived_filters = {}
    end
    
    insta_filter_amount do |insta|
      insta.amount_attributes = [:amount_recommended]
    end
    insta_formbuilder
    insta_workflow do |insta|
      insta.add_state_to_english :new, 'Pending Approval', 'new'
      insta.add_state_to_english :approved, 'Approved', 'approved'
      insta.add_event_to_english :approve, 'Approve'
    end
    
    insta_realtime do |insta|
      insta.delta_attributes = SEARCH_ATTRIBUTES
      insta.updated_by_field = :updated_by_id
      insta.suppress_when = (lambda do |model|
        # Don't generate an RTU for records that are nil or original
        !model || model.original?
      end)
    end
    
    send :include, AASM
    add_aasm
    add_sphinx if respond_to?(:sphinx_indexes) && !(connection.adapter_name =~ /SQLite/i)
  end

  class_methods do
    def model_name
      u = ActiveModel::Name.new RequestAmendment
      u.instance_variable_set '@human', 'Amendment'
      u
    end
    
    def add_aasm
      aasm_column :state
      aasm_initial_state :approved

      aasm_state :new
      aasm_state :approved

      aasm_event :approve do
        transitions :from => :new, :to => :approved
      end
    end
    
    def add_sphinx
      # Allow the overriding of the state name
      state_name = if self.respond_to? :sphinx_state_name
        self.sphinx_state_name
      else
        'state'
      end
      
      define_index :request_amendment_first do
        # fields
        indexes request.program_organization.name, :as => :request_org_name, :sortable => true
        indexes request.program_organization.acronym, :as => :request_org_acronym, :sortable => true
        indexes "if(requests.type = 'FipRequest', concat('FG-',requests.base_request_id), concat('G-',requests.base_request_id))", :as => :request_grant_id, :sortable => true

        # attributes
        has created_at, updated_at, duration, start_date, end_date, original, request_id
        has "request_amendments.#{state_name}", :type => :string, :crc => true, :as => :filter_state
        has request_type, :type => :string, :crc => true, :as => :request_type
        has "ROUND(request_amendments.amount_recommended)", :as => :amount_recommended, :type => :integer
        has request.program_lead(:id), :as => :lead_user_ids
        has FluxxGrantSphinxHelper.request_hierarchy, :type => :multi, :as => :request_hierarchy

        set_property :delta => :delayed
      end
    end
  end

  instance_methods do
    def is_approved?
      approved_state = RequestAmendment.all_states_with_category('approved').first
      state.to_s == approved_state.to_s if approved_state
    end
    
    def is_original?
      self.original
    end
    
    def all_related_requests
      [request]
    end
    
    def related_grants
      [request]
    end
    
    def title
      "Amendment to #{self.request ? self.request.grant_or_request_id : ''}"
    end
    
    def request_hierarchy
      "#{request ? request.program_id : ''}-#{request ? request.sub_program_id : ''}-#{request ? request.initiative_id : ''}-#{request ? request.sub_initiative_id : ''}"
    end
    
    def filter_state
      request ? request.state : nil
    end
    
    def lead_user_ids
      (request && request.program_lead) ? request.program_lead.id : nil
    end
    
  end
end
