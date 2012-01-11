module FluxxProgramBudget
  extend FluxxModuleHelper

  SEARCH_ATTRIBUTES = [:program_id, :created_at, :updated_at, :id]
  
  when_included do
    belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
    belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'

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
      insta.filename = 'program_budget'
      insta.headers = [['Date Created', :date], ['Date Updated', :date]]
      insta.sql_query = "created_at, updated_at
                from program_budgets
                where id IN (?)"
    end
    insta_lock

    insta_template do |insta|
      insta.entity_name = 'program_budget'
      insta.add_methods []
      insta.remove_methods [:id]
    end

    insta_utc do |insta|
      insta.time_attributes = [] 
    end
    insta_filter_amount do |insta|
      insta.amount_attributes = [:amount]
    end
    
  end
  
  class_methods do
    # Given a configuration of program_id/sub_program_id/initiative_id/sub_initiative_id/spending_year, find the total of all non-deleted program budgets
    # that meet that criteria
    def total_sub_budget_amount options
      spending_year = options[:spending_year]
      program_id = options[:program_id]
      sub_program_id = options[:sub_program_id]
      initiative_id = options[:initiative_id]
      sub_initiative_id = options[:sub_initiative_id]
      
      # Find all the valid allocations for this program budget and join that against the program budgets table to try to understand how much 
      # money has been budgeted for the allocations
      sql_statement = if program_id
        "select sum(program_budgets.amount) from program_budgets
          where program_id is null and 
          (sub_program_id in (select id from sub_programs where program_id = #{program_id}) or
            initiative_id in (select id from initiatives where sub_program_id in (select id from sub_programs where program_id = #{program_id})) or
            sub_initiative_id in (select id from sub_initiatives where initiative_id in (select id from initiatives where sub_program_id in  (select id from sub_programs where program_id = #{program_id})))) and
          program_budgets.spending_year = #{spending_year} and 
          program_budgets.deleted_at is null"
      elsif sub_program_id
        "select sum(program_budgets.amount) from program_budgets 
          where program_id is null and sub_program_id is null and
          (initiative_id in (select id from initiatives where sub_program_id = #{sub_program_id}) or
            sub_initiative_id in (select id from sub_initiatives where initiative_id in (select id from initiatives where sub_program_id = #{sub_program_id}))) and
          program_budgets.spending_year = #{spending_year} and 
          program_budgets.deleted_at is null"
      elsif initiative_id
        "select sum(program_budgets.amount) from program_budgets
          where program_id is null and sub_program_id is null and initiative_id is null and 
          sub_initiative_id in (select id from sub_initiatives where initiative_id = #{initiative_id}) and
          program_budgets.spending_year = #{spending_year} and 
          program_budgets.deleted_at is null"
      else
        "select 0"
      end
      ProgramBudget.connection.select_value sql_statement
    end
  end
  
  instance_methods do
  end
end