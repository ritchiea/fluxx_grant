module FluxxProgram
  LIQUID_METHODS = [:name]

  def self.included(base)
    base.acts_as_audited

    base.has_many :sub_programs
    base.validates_presence_of     :name
    base.validates_length_of       :name,    :within => 3..255

    base.belongs_to :parent_program, :class_name => 'Program', :foreign_key => :parent_id
    base.has_many :children_programs, :class_name => 'Program', :foreign_key => :parent_id
    
    base.insta_search
    base.insta_export
    base.insta_realtime
    base.insta_multi
    base.insta_template do |insta|
      insta.entity_name = 'program'
      insta.add_methods []
      insta.remove_methods [:id]
    end
    base.liquid_methods *( LIQUID_METHODS )

    base.extend(ModelClassMethods)
    base.class_eval do
      include ModelInstanceMethods
    end
  end

  module ModelClassMethods
    def finance_administrator_role_name
      'Finance Administrator'
    end

    def grants_administrator_role_name
      'Grants Administrator'
    end

    def grants_assistant_role_name
      'Grants Assistant'
    end

    def president_role_name
      'President'
    end

    def program_associate_role_name
      'Program Associate'
    end

    def program_director_role_name
      'Program Director'
    end

    def program_officer_role_name
      'Program Officer'
    end
    
    def deputy_director_role_name
      'Deputy Directory'
    end

    def cr_role_name
      'CR'
    end

    def svp_role_name
      'SVP'
    end

    def request_roles
      [president_role_name, program_associate_role_name, program_officer_role_name, program_director_role_name, cr_role_name, deputy_director_role_name, svp_role_name, grants_administrator_role_name, grants_assistant_role_name]
    end

    def grant_roles
      [grants_administrator_role_name, grants_assistant_role_name]
    end

    def finance_roles
      [finance_administrator_role_name]
    end
    
    def all_role_names
      (request_roles + grant_roles + finance_roles).uniq
    end

    def all_program_users
      User.joins(:role_users).where({:role_users => {:roleable_type => self.name}}).group("users.id").compact
    end

    def load_all
      Program.where(:retired => 0).all
    end
  end

  module ModelInstanceMethods
    
    def load_sub_programs minimum_fields=true
      select_field_sql = if minimum_fields
        'description, name, id, program_id'
      else
        'sub_programs.*'
      end
      SubProgram.find :all, :select => select_field_sql, :conditions => ['program_id = ?', id], :order => :name
    end

    def load_users role_name=nil
      user_query = User.joins(:role_users).where({:test_user_flag => 0, :role_users => {:roleable_type => self.class.name, :roleable_id => self.id}})
      user_query = user_query.where({:role_users => {:name => role_name}}) if role_name
      user_query.group("users.id").compact
    end
    
    def funding_source_allocations options={}
      spending_year_clause = options[:spending_year] ? " spending_year = #{options[:spending_year]} and " : ''
      retired_clause = options[:show_retired] ? " retired != 1 or retired is null " : ''

      FundingSourceAllocation.find_by_sql(FundingSourceAllocation.send(:sanitize_sql, ["select funding_source_allocations.* from funding_source_allocations where 
        #{spending_year_clause}
          (program_id = ?
          or sub_program_id in (select id from sub_programs where program_id = ?)
          or initiative_id in (select initiatives.id from initiatives, sub_programs where sub_program_id = sub_programs.id and sub_programs.program_id = ?)
          or sub_initiative_id in (select sub_initiatives.id from sub_initiatives, initiatives, sub_programs where initiative_id = initiatives.id and sub_program_id = sub_programs.id and sub_programs.program_id = ?))", 
        self.id, self.id, self.id, self.id]))
    end
    
    def total_allocation options={}
      spending_year_clause = options[:spending_year] ? " spending_year = #{options[:spending_year]} and " : ''
      total_amount = FundingSourceAllocation.connection.execute(
          FundingSourceAllocation.send(:sanitize_sql, ["select sum(amount) from funding_source_allocations where 
            #{spending_year_clause}
            (program_id = ?
              or sub_program_id in (select id from sub_programs where program_id = ?)
              or initiative_id in (select initiatives.id from initiatives, sub_programs where sub_program_id = sub_programs.id and sub_programs.program_id = ?)
              or sub_initiative_id in (select sub_initiatives.id from sub_initiatives, initiatives, sub_programs where initiative_id = initiatives.id and sub_program_id = sub_programs.id and sub_programs.program_id = ?))", 
            self.id, self.id, self.id, self.id]))
      total_amount.fetch_row.first.to_i
    end
    
    def autocomplete_to_s
      description || name
    end

    def to_s
      autocomplete_to_s
    end
  end
end