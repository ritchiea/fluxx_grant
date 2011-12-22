module FluxxFundingSource
SEARCH_ATTRIBUTES = [:state]
  
  def self.included(base)
    base.has_many :request_funding_sources
    base.has_many :funding_source_allocations, :conditions => {:deleted_at => nil}
    base.belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
    base.belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'
    base.belongs_to :narrative_lead_user, :class_name => 'User', :foreign_key => 'narrative_lead_user_id'
    base.has_many :notes, :as => :notable, :conditions => {:deleted_at => nil}
    base.before_destroy :clear_out_allocation_references
    base.acts_as_audited

    base.insta_search do |insta|
      insta.filter_fields = SEARCH_ATTRIBUTES
    end
    base.insta_export
    base.insta_realtime
    base.insta_filter_amount do |insta|
      insta.amount_attributes = [:amount, :amount_requested, :amount_budgeted, :overhead_amount, :net_available_to_spend_amount]
    end
    
    base.extend(ModelClassMethods)
    base.class_eval do
      include ModelInstanceMethods
    end
    base.insta_template do |insta|
      insta.entity_name = 'fluxx_funding_source'
      insta.add_methods [:name]
      insta.remove_methods [:id]
    end
    
    base.insta_workflow do |insta|
      insta.add_state_to_english :new, 'Pending Approval', 'new'
      insta.add_state_to_english :approved, 'Ready to Spend', 'approved'
      insta.add_event_to_english :approve, 'Approve'
    end
    base.send :include, AASM
    base.add_aasm
  end

  module ModelClassMethods
    def load_all
      FundingSource.where(:retired => 0).order(:name).all
    end
    
    def add_aasm
      aasm_column :state
      aasm_initial_state :new

      aasm_state :new
      aasm_state :approved

      aasm_event :approve do
        transitions :from => :new, :to => :approved
      end
    end
    
    def approved_states
      'approved'
    end
  end

  module ModelInstanceMethods
    def amount_available
      funding_source_allocations.inject(amount || 0){|acc, fsa| acc - (fsa.amount || 0)}
    end
    
    def load_funding_source_allocations options={}
      spending_year_clause = options[:spending_year] ? " spending_year = #{options[:spending_year]} and " : ''

      FundingSourceAllocation.find_by_sql(FundingSourceAllocation.send(:sanitize_sql, ["select fsa.* from funding_source_allocations fsa where 
        #{spending_year_clause}
        funding_source_id = ?
        and deleted_at is null",
          self.id]))
    end
    
    def is_approved?
      true
    end
    
    def clear_out_allocation_references
      FundingSourceAllocation.where(:funding_source_id => self.id).where('deleted_at is not null').update_all(:funding_source_id => nil)
    end
  end
end