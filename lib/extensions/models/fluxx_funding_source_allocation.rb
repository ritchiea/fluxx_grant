module FluxxFundingSourceAllocation
  SEARCH_ATTRIBUTES = [:created_at, :updated_at, :id, :program_id, :sub_program_id, :initiative_id, :sub_initiative_id, :spending_year]
  
  def self.included(base)
    base.belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
    base.belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'
    base.belongs_to :funding_source
    base.belongs_to :program
    base.belongs_to :sub_program
    base.belongs_to :initiative
    base.belongs_to :sub_initiative
    base.has_many :request_funding_sources, :include => :request, :conditions => "requests.deleted_at is null"
    base.has_many :funding_source_allocation_authorities
    base.validates_presence_of :funding_source
    base.validates_presence_of :spending_year

    base.acts_as_audited({:full_model_enabled => false, :except => [:created_by_id, :updated_by_id, :delta, :updated_by, :created_by, :audits]})

    base.insta_search do |insta|
      insta.filter_fields = SEARCH_ATTRIBUTES
      insta.derived_filters = {}
    end

    base.insta_multi
    base.insta_export do |insta|
      insta.filename = 'funding_source_allocation'
      insta.headers = [['Date Created', :date], ['Date Updated', :date]]
      insta.sql_query = "created_at, updated_at
                from funding_source_allocations
                where id IN (?)"
    end
    base.insta_lock

    base.insta_utc do |insta|
      insta.time_attributes = [] 
    end
    base.insta_filter_amount do |insta|
      insta.amount_attributes = [:amount, :budget_amount, :actual_budget_amount]
    end
    base.insta_template do |insta|
      insta.entity_name = 'funding_source_allocation'
      insta.add_methods [:spending_year, :funding_source]
      insta.remove_methods [:id]
    end
    

    base.extend(ModelClassMethods)
    base.class_eval do
      include ModelInstanceMethods
    end
    
  end
  

  module ModelClassMethods
    def build_temp_table limit_to_approved_funding_sources=true
      temp_table = self.name.underscore + "_tmp"
      FundingSourceAllocation.connection.execute "DROP TABLE IF EXISTS #{temp_table}"
      
      fsa_sql = "create temporary table #{temp_table} 
        select funding_source_allocations.id, 
          if(program_id is not null, program_id, 
            if(sub_program_id is not null, (select program_id from sub_programs where id = sub_program_id),
              if(initiative_id is not null, (select program_id from sub_programs where id = (select sub_program_id from initiatives where initiatives.id = initiative_id)), 
                if(sub_initiative_id is not null, (select program_id from sub_programs where id = (select sub_program_id from initiatives where initiatives.id = (select initiative_id from sub_initiatives where sub_initiatives.id = sub_initiative_id))), null)))) program_id,
          if(sub_program_id is not null, sub_program_id,
      			if(initiative_id is not null, (select sub_program_id from initiatives where initiatives.id = initiative_id),
              if(sub_initiative_id is not null, (select sub_program_id from initiatives where initiatives.id = (select initiative_id from sub_initiatives where sub_initiatives.id = sub_initiative_id)), null))) sub_program_id,
       		if(initiative_id is not null, initiative_id, 
            if(sub_initiative_id is not null, (select initiative_id from sub_initiatives where sub_initiatives.id = sub_initiative_id), null)) initiative_id,
          sub_initiative_id,
         deleted_at, spending_year, retired, amount, funding_source_id
         from funding_source_allocations"
      fsa_sql += FundingSourceAllocation.send(:sanitize_sql, [" where funding_source_id in (select id from funding_sources where state in (?))", FundingSource.approved_states]) if limit_to_approved_funding_sources
      
      FundingSourceAllocation.connection.execute(fsa_sql)
      retval = yield temp_table
      FundingSourceAllocation.connection.execute("DROP TABLE IF EXISTS #{temp_table}")
      retval
    end

    def find_by_category params
      if params[:program_id]
        programs = Program.where("id in (?) OR  parent_id in (?)", params[:program_id], params[:program_id])
        sub_programs = SubProgram.where(:program_id => programs)
        initiatives = Initiative.where(:sub_program_id => sub_programs)
        sub_initiatives = SubInitiative.where(:initiative_id => initiatives)
        self.where("deleted_at is null and program_id in (?) or sub_program_id in (?) or initiative_id in (?) or sub_initiative_id in (?)", programs, sub_programs, initiatives, sub_initiatives)
      elsif params[:initiative_id]
        initiatives = Initiative.where(:id => params[:initiative_id])
        sub_initiatives = SubInitiative.where(:initiative_id => initiatives)
        self.where("deleted_at is null and initiative_id in (?) or sub_initiative_id in (?)", initiatives, sub_initiatives)
      end
    end
  end
  
  module ModelInstanceMethods
    def amount_granted request_type = nil
      request_funding_sources.select{|rfs| !rfs.request.nil? && rfs.request.granted && (!request_type || rfs.request.type == request_type)}.inject(0){|acc, rfs| acc + (rfs.funding_amount || 0)}
    end

    def number_granted request_type = nil
      requests = []
      request_funding_sources.select{|rfs| !rfs.request.nil? && rfs.request.granted && (!request_type || rfs.request.type == request_type)}.map{|rfs| rfs.request.id}.uniq.count
    end

    def amount_remaining
      (amount || 0) - (amount_granted || 0)
    end

    # Pipeline
    def amount_granted_in_queue request_type = nil
      request_funding_sources.reject{|rfs| rfs.request.nil? || rfs.request.granted || Request.all_rejected_states.include?(rfs.request.state.to_sym) || rfs.request.deleted_at || (request_type && rfs.request.type != request_type)}.inject(0){|acc, rfs| acc + (rfs.funding_amount || 0)}
    end

    def number_granted_in_queue request_type = nil
      request_funding_sources.reject{|rfs| rfs.request.nil? || rfs.request.granted || Request.all_rejected_states.include?(rfs.request.state.to_sym) || rfs.request.deleted_at || (request_type && rfs.request.type != request_type)}.map{|rfs| rfs.request.id}.uniq.count
    end
    
    # Look at each funding source transaction associated with each funding source associated with this allocation and sum up the amount paid
    def amount_paid request_type = nil
      a = unless (request_type)
        RequestTransactionFundingSource.find_by_sql ["select sum(request_transaction_funding_sources.amount) paid_amount
        from request_funding_sources, request_transaction_funding_sources, request_transactions
        where
        request_transaction_funding_sources.request_funding_source_id = request_funding_sources.id and
        request_transaction_funding_sources.request_transaction_id = request_transactions.id and
        funding_source_allocation_id = ? and
        request_transactions.deleted_at is null and
        request_transactions.state = 'paid'", self.id]
      else
        RequestTransactionFundingSource.find_by_sql ["select sum(request_transaction_funding_sources.amount) paid_amount
        from request_funding_sources, request_transaction_funding_sources, request_transactions, requests
        where
        request_transaction_funding_sources.request_funding_source_id = request_funding_sources.id and
        request_transaction_funding_sources.request_transaction_id = request_transactions.id and
        request_funding_sources.request_id = requests.id and
        requests.type = ? and
        funding_source_allocation_id = ? and
        request_transactions.deleted_at is null and
        request_transactions.state = 'paid'", request_type, self.id]
      end
      if a && a.is_a?(Array)
        (a.first.paid_amount ? a.first.paid_amount.to_i : 0)
      end || 0
    end

    #TODO AML: Combine amount_paid and number_paid?
    def number_paid request_type = nil
      a = unless (request_type)
        RequestTransactionFundingSource.find_by_sql ["select count(DISTINCT requests.id) paid_count
        from request_funding_sources, request_transaction_funding_sources, request_transactions
        where
        request_transaction_funding_sources.request_funding_source_id = request_funding_sources.id and
        request_transaction_funding_sources.request_transaction_id = request_transactions.id and
        funding_source_allocation_id = ? and
        request_transactions.deleted_at is null and
        request_transactions.state = 'paid'", self.id]
      else
        RequestTransactionFundingSource.find_by_sql ["select count(DISTINCT requests.id) paid_count
        from request_funding_sources, request_transaction_funding_sources, request_transactions, requests
        where
        request_transaction_funding_sources.request_funding_source_id = request_funding_sources.id and
        request_transaction_funding_sources.request_transaction_id = request_transactions.id and
        request_funding_sources.request_id = requests.id and
        requests.type = ? and
        funding_source_allocation_id = ? and
        request_transactions.deleted_at is null and
        request_transactions.state = 'paid'", request_type, self.id]
      end
      if a && a.is_a?(Array)
        (a.first.paid_count ? a.first.paid_count.to_i : 0)
      end || 0
    end

    def derive_program
      if sub_initiative
        sub_initiative.initiative.sub_program.program if sub_initiative.initiative && sub_initiative.initiative.sub_program
      elsif initiative
        initiative.sub_program.program if initiative.sub_program
      elsif sub_program
        sub_program.program
      else
        program
      end
    end

    def derive_sub_program
      if sub_initiative
        sub_initiative.initiative.sub_program if sub_initiative.initiative
      elsif initiative
        initiative.sub_program
      else
        sub_program
      end
    end

    def derive_initiative
      if sub_initiative
        sub_initiative.initiative
      else
        initiative
      end
    end
    
    def derive_sub_initiative
      sub_initiative
    end
    
    # Only sub_initiative/initiative/sub_program/program is populated so we need to figure out which one is populated and derive from that
    def program_display_name
      obj = derive_program
      obj.name if obj
    end

    # Only sub_initiative/initiative/sub_program/program is populated so we need to figure out which one is populated and derive from that
    def sub_program_display_name
      obj = derive_sub_program
      obj.name if obj
    end

    def initiative_display_name
      obj = derive_initiative
      obj.name if obj
    end

    def sub_initiative_display_name
      sub_initiative.name if sub_initiative
    end
    
    def composite_name
      program_name = program.name if program
      sub_program_name = sub_program.name if sub_program
      initiative_name = initiative.name if initiative
      sub_initiative_name = sub_initiative.name if sub_initiative
      "#{funding_source ? funding_source.name : ''} - #{program_name} - #{sub_program_name} - #{initiative_name} - #{sub_initiative_name}"
    end
    def title
      "#{composite_name}; Total: #{amount}, Remaining: #{(amount || 0) - (amount_granted || 0)}"
    end
    
    def funding_source_title request_amount=nil
      current_amount_remaining = self.amount_remaining
      funds_available = if request_amount
        if current_amount_remaining >= request_amount
          "#{current_amount_remaining.to_currency} (#{amount_granted_in_queue.to_currency} in pipeline)"
        else
          "Less than #{request_amount.to_currency} available"
        end
      else
        "#{current_amount_remaining.to_currency} (#{amount_granted_in_queue.to_currency} in pipeline)"
      end
      "#{self.funding_source ? self.funding_source.name : ''}: #{funds_available}"
    end
    
    def autocomplete_to_s
      title
    end
    
    def recalculate_amount
      if self.deleted_at
        self.update_attribute :amount, 0
      else
        self.update_attribute :amount, self.funding_source_allocation_authorities.inject(0){|acc, fsaa| acc + (fsaa.amount || 0)}
        self.safe_delete if self.funding_source_allocation_authorities.size == 0
      end
    end
  end
end