module FluxxSubInitiative
  SEARCH_ATTRIBUTES = [:created_at, :updated_at, :id, [:program_id, 'sub_programs'], [:sub_program_id, 'initiatives'], :initiative_id, :retired]
  SUB_INITIATIVE_FSA_JOIN_WHERE_CLAUSE = "(fsa.sub_initiative_id = ?) and fsa.deleted_at is null"
  SUB_INITIATIVE_FSA_JOIN_FUNDING_SOURCE_CLAUSE = "funding_source_id in (select id from funding_sources where state in (?))"
  
  def self.included(base)
    base.belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
    base.belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'
    base.belongs_to :initiative
    base.before_destroy :clear_out_allocation_references
    base.has_many :notes, :as => :notable, :conditions => {:deleted_at => nil}
    base.send :attr_accessor, :not_retired

    base.acts_as_audited({:full_model_enabled => false, :except => [:created_by_id, :updated_by_id, :delta, :updated_by, :created_by, :audits]})
    base.insta_export do |insta|
      insta.spreadsheet_template = "sub_initiative_spreadsheet"
      insta.filename = 'sub_initiative'
      insta.headers = [['Date Created', :date], ['Date Updated', :date], 'Name', 'Spending Year', ['Amount Funded', :currency]]
      insta.sql_query = "            sub_initiatives.created_at, sub_initiatives.updated_at, sub_initiatives.name, if(spending_year is null, 'none', spending_year), sum(amount)
                   from sub_initiatives
                   left outer join funding_source_allocations fsa on true
                    where
                   #{SUB_INITIATIVE_FSA_JOIN_WHERE_CLAUSE.gsub /\?/, 'sub_initiatives.id'}
                      and sub_initiatives.id IN (?)
                      group by name, if(spending_year is null, 0, spending_year)
                  "
    end

    base.insta_search do |insta|
      insta.filter_fields = SEARCH_ATTRIBUTES
      insta.derived_filters = {}
    end
    
    base.extend(ModelClassMethods)
    base.class_eval do
      include ModelInstanceMethods
    end
  end

  module ModelClassMethods
    def is_hidden?
      Fluxx.config(:hide_sub_initiative) == "1" && Fluxx.config(:funding_source_allocation_hide_sub_initiative) == "1"
    end

    def load_all
      SubInitiative.where(:retired => 0).order(:name).all
    end

    def model_name
      u = ActiveModel::Name.new SubInitiative
      u.instance_variable_set '@human', I18n.t(:sub_initiative_name)
      u
    end
  end
  
  module ModelInstanceMethods
    def autocomplete_to_s
      description || name
    end

    def to_s
      autocomplete_to_s
    end
    
    def program_id
      program.id if program
    end
    def program_id= program_id
      # no-op to make the form happy ;)
    end
    
    def program
      sub_program.program if sub_program
    end
    
    def sub_program_id
      sub_program.id if sub_program
    end
    def sub_program_id= sub_program_id
      # no-op to make the form happy ;)
    end
    
    def sub_program
      initiative.sub_program if initiative
    end

      
    def sub_initiative_fsa_join_where_clause restrict_to_approved=true
      if restrict_to_approved
        "#{SUB_INITIATIVE_FSA_JOIN_WHERE_CLAUSE} AND #{SUB_INITIATIVE_FSA_JOIN_FUNDING_SOURCE_CLAUSE}"
      else
        SUB_INITIATIVE_FSA_JOIN_WHERE_CLAUSE
      end
    end
   
    def funding_source_allocations options={}
      spending_year_clause = options[:spending_year] ? " spending_year = #{options[:spending_year]} and " : ''
      retired_clause = options[:show_retired] ? " retired != 1 or retired is null " : ''

      base_query = "select fsa.*,
        (select count(*) from funding_source_allocation_authorities where funding_source_allocation_id = fsa.id) num_allocation_authorities
        from funding_source_allocations fsa where 
        #{spending_year_clause}"

      clause = if options[:show_unapproved]
        [ "#{base_query} #{sub_initiative_fsa_join_where_clause(false)}", 
        self.id]
      else
        [ "#{base_query} #{sub_initiative_fsa_join_where_clause(true)}", 
        self.id, FundingSource.approved_states]
      end

      FundingSourceAllocation.find_by_sql(FundingSourceAllocation.send(:sanitize_sql, clause))
    end

    def total_pipeline request_types=nil, spending_year=nil
      pipeline_spending_year_clause = FundingSourceAllocation.send(:sanitize_sql, [" and fsa.spending_year = ? ", spending_year]) if spending_year
      total_amount = FundingSourceAllocation.connection.execute(
          FundingSourceAllocation.send(:sanitize_sql, ["select sum(rfs.funding_amount) from funding_source_allocations fsa, request_funding_sources rfs, requests where 
          requests.granted = 0 and
          requests.deleted_at IS NULL AND requests.state <> 'rejected' and
        rfs.request_id = requests.id 
        #{Request.prepare_request_types_for_where_clause(request_types)}
        #{pipeline_spending_year_clause}
        and rfs.funding_source_allocation_id = fsa.id and
                #{sub_initiative_fsa_join_where_clause}",self.id, FundingSource.approved_states]))
      total_amount.fetch_row.first.to_i
    end

    def total_allocation options={}
      spending_year_clause = options[:spending_year] ? " spending_year = #{options[:spending_year]} and " : ''
      total_amount = FundingSourceAllocation.connection.execute(
          FundingSourceAllocation.send(:sanitize_sql, ["select sum(amount) from funding_source_allocations fsa where 
            #{spending_year_clause}
            #{sub_initiative_fsa_join_where_clause}", 
            self.id, FundingSource.approved_states]))
      total_amount.fetch_row.first.to_i
    end

    def clear_out_allocation_references
      FundingSourceAllocation.where(:sub_initiative_id => self.id).where('deleted_at is not null').update_all(:sub_initiative_id => nil)
      Request.where(:sub_initiative_id => self.id).where('deleted_at is not null').update_all(:sub_initiative_id => nil)
    end
  end
end