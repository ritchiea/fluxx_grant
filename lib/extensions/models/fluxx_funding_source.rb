module FluxxFundingSource
  LIQUID_METHODS = [ :name ]  

  def self.included(base)
    base.has_many :request_funding_sources
    base.has_many :funding_source_allocations, :conditions => {:deleted_at => nil}
    base.belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
    base.belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'
    base.acts_as_audited

    base.insta_search
    base.insta_export
    base.insta_realtime
    base.insta_filter_amount do |insta|
      insta.amount_attributes = [:amount]
    end
    base.liquid_methods *( LIQUID_METHODS )    
    
    base.extend(ModelClassMethods)
    base.class_eval do
      include ModelInstanceMethods
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
      self.in_state_with_category? 'approved'
    end
  end
end