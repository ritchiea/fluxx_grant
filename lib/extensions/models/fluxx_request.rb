module FluxxRequest
  def self.prepare_from_date search_with_attributes, name, val
    if (Time.parse_localized(val) rescue nil)
      start_at = Time.parse_localized(val)
      if search_with_attributes[name] && search_with_attributes[name].end < FAR_IN_THE_FUTURE
        search_with_attributes[name] = ((start_at.to_i-1)..(search_with_attributes[name].end))
      else
        search_with_attributes[name] = ((start_at.to_i-1)..FAR_IN_THE_FUTURE.to_i)
      end
      search_with_attributes
    end || {}
  end
  
  def self.prepare_to_date search_with_attributes, name, val
    if (Time.parse_localized(val) rescue nil)
      end_at = Time.parse_localized(val)
      if search_with_attributes[name] && search_with_attributes[name].begin > 0
        search_with_attributes[name] = ((search_with_attributes[name].begin)..end_at.to_i)
      else
        search_with_attributes[name] = (0..end_at.to_i)
      end
      search_with_attributes
    end || {}
  end
  
  def self.prepare_program_ids search_with_attributes, name, val
    program_id_strings = val
    programs = Program.where(:id => program_id_strings).all.compact
    program_ids = programs.map do |program| 
      children = program.children_programs
      if children.empty?
        program
      else
        [program] + children
      end
    end.compact.flatten.map &:id
    
    if program_ids && !program_ids.empty?
      search_with_attributes[name] = program_ids
    end
  end


  
  SEARCH_ATTRIBUTES = [:program_id, :sub_program_id, :created_by_id, :filter_state, :program_organization_id, :fiscal_organization_id, :favorite_user_ids, :lead_user_ids, :org_owner_user_ids, :granted, :filter_type, :request_hierarchy, :allocation_hierarchy, :model_theme_id]
  FAR_IN_THE_FUTURE = Time.now + 1000.year
  begin FAR_IN_THE_FUTURE.to_i rescue FAR_IN_THE_FUTURE = Time.now + 10.year end

  def self.included(base)
    base.send :include, AASM
    base.belongs_to :program_organization, :class_name => 'Organization', :foreign_key => :program_organization_id
    base.send :attr_accessor, :program_organization_lookup
    base.belongs_to :fiscal_organization, :class_name => 'Organization', :foreign_key => :fiscal_organization_id
    base.send :attr_accessor, :fiscal_organization_lookup
    base.has_many :request_organizations
    base.has_many :request_amendments
    base.has_many :request_users
    base.has_many :project_requests
    base.has_many :projects, :through => :project_requests, :conditions => {:deleted_at => nil}
    base.has_many :request_transactions, :order => "due_at asc", :conditions => {:deleted_at => nil}
    base.has_many :budget_requests, :foreign_key => :request_id, :conditions => {:deleted_at => nil}
    base.accepts_nested_attributes_for :request_transactions, :allow_destroy => true
    base.has_many :request_funding_sources
    base.has_many :request_evaluation_metrics
    base.belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'
    base.has_many :wiki_documents, :as => :model
    base.acts_as_audited({:full_model_enabled => false, :except => [:created_by_id, :modified_by_id, :locked_until, :locked_by_id, :delta, :updated_by, :created_by, :audits]})

    base.belongs_to :program
    base.belongs_to :sub_program
    base.belongs_to :initiative
    base.belongs_to :sub_initiative
    base.before_update :update_warnings_note
    base.after_create :generate_request_id
    base.after_save :process_before_save_blocks
    base.after_save :handle_cascading_deletes
    base.before_save :build_amendment
    
    # base.after_commit :update_related_data
    base.send :attr_accessor, :before_save_blocks

    base.has_many :request_reports, :conditions => 'request_reports.deleted_at IS NULL', :order => "due_at desc"
    base.has_many :letter_request_reports, :class_name => 'RequestReport', :foreign_key => :request_id, :conditions => "request_reports.deleted_at IS NULL AND request_reports.report_type <> 'Eval'", :order => "due_at"
    base.accepts_nested_attributes_for :request_reports, :allow_destroy => true
    
    base.has_many :request_programs
    base.has_many :un_approved_request_programs, :class_name => 'RequestProgram', :foreign_key => 'request_id', :conditions => {:state => 'new'}
    base.accepts_nested_attributes_for :request_programs, :allow_destroy => true
    base.has_many :secondary_programs, :class_name => 'Program', :through => :request_programs, :source => :program
    
    base.belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
    base.belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'
    
    base.belongs_to :program_lead, :class_name => 'User', :foreign_key => 'program_lead_id'
    base.belongs_to :grantee_org_owner, :class_name => 'User', :foreign_key => 'grantee_org_owner_id'
    base.belongs_to :grantee_signatory, :class_name => 'User', :foreign_key => 'grantee_signatory_id'
    base.belongs_to :fiscal_org_owner, :class_name => 'User', :foreign_key => 'fiscal_org_owner_id'
    base.belongs_to :fiscal_signatory, :class_name => 'User', :foreign_key => 'fiscal_signatory_id'

    base.has_many :request_reviews, :conditions => 'request_reviews.deleted_at IS NULL'
    base.has_many :request_reviewer_assignments
    base.has_many :request_reviewers, :class_name => 'User', :through => :request_reviewer_assignments, :source => :user
    base.belongs_to :reviewer_group, :class_name => 'Group', :foreign_key => 'reviewer_group_id'
    
    base.insta_favorite

    base.insta_lock
    base.insta_export do |insta|
      #insta.spreadsheet_template = "grant_requests/grant_request_spreadsheet"
      insta.filename = (lambda { |with_clause| (with_clause != nil && with_clause[:granted]==1) ? 'grant' : 'request'})
      insta.headers = (lambda do |with_clause|
          block1 = ['Request ID', 'Request Type', 'Status', ['Amount Requested', :currency], ['Amount Recommended', :currency]]
          grant_block = [['Amount Funded', :currency], ['Total Paid', :currency], ['Total Due', :currency], ['Grant Agreement Date', :date], ['Grant Start Date', :date], ['Grant End Date', :date]]
          block2 = ['Grantee', 'Grantee Street Address', 'Grantee Street Address2', 'Grantee City', 'Grantee State', 'Grantee Country', 'Grantee Postal Code', 'Grantee URL', 'Grantee Tax Status', 'Grantee Tax ID',
            'Fiscal Org', 'Fiscal Street Address', 'Fiscal Street Address2', 'Fiscal City', 'Fiscal State', 'Fiscal Country', 'Fiscal Postal Code', 'Fiscal URL', 'Fiscal Tax Status', 'Fiscal Tax ID',
            'Lead PO/PD', 'Program', 'Sub Program', ['Date Request Received', :date], ['Duration', :integer], 
            'Type of Org', 'Funding Source',
            ['Final Proposal Date', :date],
            ['Final Budget Date', :date],
            ['Date Created', :date], ['Date Last Updated', :date],
            'Primary Contact First Name', 'Primary Contact Last Name', 'Primary Contact Email',
            'Program Lead First Name', 'Program Lead Last Name', 'Program Lead Contact Email',
            'Signatory First Name', 'Signatory Last Name', 'Signatory Email', "#{I18n.t(:fip_name)} Title",
            'Request Summary']
          if with_clause && with_clause[:granted]==1
            block1 + grant_block + block2
          else
            block1 + block2
          end
        end)
      insta.spreadsheet_cells = (lambda do |with_clause|
        block1 = [:grant_or_request_id, :type, :state, :amount_requested, :amount_recommended]
        grant_block = [:amount_recommended, :amount_funded, :amount_pending, :grant_agreement_at, :grant_begins_at, :grant_ends_at]
        block2 = [[:program_organization, :name], [:program_organization, :street_address], [:program_organization, :street_address2], [:program_organization, :city], [:program_organization, :geo_state, :name], [:program_organization, :geo_country, :name], [:program_organization, :postal_code], [:program_organization, :url], [:program_organization, :tax_class], [:program_orgranization, :tax_id],
                    [:fiscal_organization, :name], [:fiscal_organization, :street_address], [:fiscal_organization, :street_address2], [:fiscal_organization, :city], [:fiscal_organization, :geo_state, :name], [:fiscal_organization, :geo_country, :name], [:fiscal_organization, :postal_code], [:fiscal_organization, :url], [:fiscal_organization, :tax_class], [:fiscal_organization, :tax_id],
                    [:program_lead_id, :full_name], [:program, :name], [:sub_program, :name], :request_received_at, :duration_in_months,
                    [:program_organization, :tax_class], :funding_source_list,
                    :ierf_proposed_end_at,
                    :ierf_budget_end_at,
                    :created_at, :updated_at,
                    [:grantee_org_owner, :first_name], [:grantee_org_owner, :last_name], [:grantee_org_owner, :email],
                    [:program_lead, :first_name], [:program_lead, :last_name], [:program_lead, :email],
                    [:grantee_signatory, :first_name], [:grantee_signatory, :last_name], [:grantee_signatory, :email],
                    :project_summary]
          if with_clause && with_clause[:granted]==1
            block1 + grant_block + block2
          else
            block1 + block2
          end
      end)

      #[:grant_or_request_id, :grant_or_request_id, :state, :amount_requested, :amount_recommended, [:program_organization, :name]]
      insta.sql_query =   (lambda do |with_clause|
          block1 = "  
          requests.base_request_id, requests.type, requests.state,
                         requests.amount_requested,
                         requests.amount_recommended,"

          grant_block =  "requests.amount_recommended amount_funded,
                         (select sum(amount_paid) from request_transactions rt where rt.request_id = requests.id) total_amount_paid, 
                         (select sum(amount_due) from request_transactions rt where rt.request_id = requests.id) total_amount_due,
                         requests.grant_agreement_at, 
                         grant_begins_at, 
                         date_add(date_add(grant_begins_at, interval duration_in_months MONTH), interval -1 DAY) grant_ends_at,"

          block2 = "program_organization.name, 
          program_organization.street_address program_org_street_address, program_organization.street_address2 program_org_street_address2, program_organization.city program_org_city,
          program_org_country_states.name program_org_state_name, program_org_countries.name program_org_country_name, program_organization.postal_code program_org_postal_code,
          program_organization.url program_org_url, (select value from multi_element_values where id = program_organization.tax_class_id) program_org_tax_class, program_organization.tax_id program_org_tax_id,
          fiscal_organization.name,
          fiscal_organization.street_address fiscal_org_street_address, fiscal_organization.street_address2 fiscal_org_street_address2, fiscal_organization.city fiscal_org_city,
          fiscal_org_country_states.name fiscal_org_state_name, fiscal_org_countries.name fiscal_org_country_name, fiscal_organization.postal_code fiscal_org_postal_code,
          fiscal_organization.url fiscal_org_url, (select value from multi_element_values where id = fiscal_organization.tax_class_id) fiscal_org_tax_class, fiscal_organization.tax_id fiscal_org_tax_id,
          (select concat(users.first_name, (concat(' ', users.last_name))) full_name from
          users where id = program_lead_id) lead_po,
          program.name, sub_program.name,
          requests.request_received_at, 
          requests.duration_in_months,
          (select replace(group_concat(mev.value, ', '), ', ', '')
          from multi_element_values mev, multi_element_groups meg, multi_element_choices mec
          WHERE   meg.name = 'constituents' and meg.target_class_name = 'Request'
          and multi_element_group_id = meg.id
          and multi_element_value_id = mev.id
          and target_id = requests.id
          group by requests.id) constituents,
          (select replace(group_concat(mev.value, ', '), ', ', '')
          from multi_element_values mev, multi_element_groups meg, multi_element_choices mec
          WHERE   (meg.name = 'usa_means' OR meg.name = 'china_means') and meg.target_class_name = 'Request'
          and multi_element_group_id = meg.id
          and multi_element_value_id = mev.id
          and target_id = requests.id
          group by requests.id) means,
          (select mev_tax_class.value from
           multi_element_groups meg_tax_class,
           multi_element_values mev_tax_class 
           WHERE meg_tax_class.name = 'tax_classes' and meg_tax_class.target_class_name = 'Request' and
           multi_element_group_id = meg_tax_class.id and program_organization.tax_class_id = mev_tax_class.id) org_tax_class,
          replace(group_concat(funding_sources.name, ', '), ', ', '') funding_source_name,
          requests.ierf_proposed_end_at,
          requests.ierf_budget_end_at,
          
          requests.created_at, requests.updated_at, 
          owner_users.first_name, owner_users.last_name, owner_users.email,
          lead_users.first_name, lead_users.last_name, lead_users.email,
          signatory_users.first_name, signatory_users.last_name, signatory_users.email, requests.fip_title,
          project_summary
                         FROM requests
                         LEFT OUTER JOIN programs program ON program.id = requests.program_id
                         LEFT OUTER JOIN sub_programs sub_program ON sub_program.id = requests.sub_program_id
                         LEFT OUTER JOIN organizations program_organization ON program_organization.id = requests.program_organization_id
                         LEFT OUTER JOIN organizations fiscal_organization ON fiscal_organization.id = requests.fiscal_organization_id
                         LEFT OUTER JOIN request_funding_sources ON request_funding_sources.request_id = requests.id
                         LEFT OUTER JOIN funding_source_allocations ON funding_source_allocations.id = request_funding_sources.funding_source_allocation_id
                         LEFT OUTER JOIN funding_sources ON funding_sources.id = funding_source_allocations.funding_source_id
                         left outer join geo_states as program_org_country_states on program_org_country_states.id = program_organization.geo_state_id
                         left outer join geo_countries as program_org_countries on program_org_countries.id = program_organization.geo_country_id
                         left outer join geo_states as fiscal_org_country_states on fiscal_org_country_states.id = fiscal_organization.geo_state_id
                         left outer join geo_countries as fiscal_org_countries on fiscal_org_countries.id = fiscal_organization.geo_country_id
                         left outer join users as owner_users on (if(requests.grantee_org_owner_id is not null, requests.grantee_org_owner_id, requests.fiscal_org_owner_id)) = owner_users.id
                         left outer join users as lead_users on requests.program_lead_id = lead_users.id
                         left outer join users as signatory_users on requests.grantee_signatory_id = signatory_users.id
                         WHERE requests.id IN (?) GROUP BY requests.id"
         if with_clause[:granted]==1 || (with_clause[:granted].is_a?(Array) && with_clause[:granted].include?(1))
           block1 + grant_block + block2
         else
           block1 + block2
         end
       end)
    end

    base.insta_multi
    base.insta_lock
    
    base.insta_template do |insta|
      insta.entity_name = 'request'
      insta.add_methods [:request_id, :grant_id, :grant_or_request_id, :project_summary, :grant_agreement_at, :grant_begins_at, :grant_ends_at, :grant_closed_at, :request_received_at, :fip_projected_end_at, :amount_requested, :amount_recommended, :duration_in_months, :program_lead, :signatory_contact, :signatory_user_org, :signatory_user_org_title, :address_org, :program, :initiative, :sub_program, :request_transactions, :request_reports, :letter_request_reports, :request_evaluation_metrics, :letter_project_summary_without_leading_to, :first_transaction, :ierf_proposed_end_at, :ierf_budget_end_at, :program_organization, :fiscal_organization, :grantee_org_owner_with_specific, :letter_project_summary, :signatory_contact_title, :request_funding_sources, :budget_requests, :state_to_english, :first_transaction, :board_authority_year, :request_received_at_year, :fiscal_sponsor_org, :initial_payment, :interim_payment, :final_payment, :initial_report, :final_report, :program_organization, :signatory_contact, :address_org, :title, :grant_id, :request_id, :grant_ends_at, :amount_funded, :funds_expended, :created_by_with_create_date ]  
      
      insta.add_list_method :request_transactions, RequestTransaction
      insta.add_list_method :request_reports, RequestReport
      insta.remove_methods [:id]
    end
    
    
    base.insta_search do |insta|
      insta.filter_fields = SEARCH_ATTRIBUTES + [:group_ids, :greater_amount_recommended, :lesser_amount_recommended, :request_from_date, :request_to_date, :grant_begins_from_date, :grant_begins_to_date, :grant_ends_from_date, :grant_ends_to_date, :missing_request_id, :has_been_rejected, :funding_source_ids, :all_request_program_ids, :request_program_ids, :multi_element_value_ids, :funding_source_allocation_program_id, :funding_source_allocation_sub_program_id, :funding_source_allocation_initiative_id, :funding_source_allocation_sub_initiative_id, :funding_source_allocation_id, :base_request_id, :ending_within_days]

      

      insta.derived_filters = {
          :ending_within_days => (lambda do |search_with_attributes, request_params, name, value|
              value = value.first if value && value.is_a?(Array)
              if value.to_s.is_numeric?
                within_days_date = Time.now + value.to_i.days
                search_with_attributes[:grant_ends_at] = (Time.now.to_i..within_days_date.to_i)
              end || {}
            end),
          :has_been_rejected => (lambda do |search_with_attributes, request_params, name, val|
            if val == '1' || (val.is_a?(Array) && val.first == '1')
              search_with_attributes.delete :has_been_rejected
            else
              search_with_attributes[:has_been_rejected] = 0
            end
          end),

          :program_id => (lambda do |search_with_attributes, request_params, name, val|
            prepare_program_ids search_with_attributes, name, val
          end),
          
          :request_program_ids => (lambda do |search_with_attributes, request_params, name, val|
            prepare_program_ids search_with_attributes, name, val
          end),
          :request_hierarchy => (lambda do |search_with_attributes, request_params, name, val|
            FluxxGrantSphinxHelper.prepare_hierarchy search_with_attributes, name, val
          end),
          :allocation_hierarchy => (lambda do |search_with_attributes, request_params, name, val|
            FluxxGrantSphinxHelper.prepare_hierarchy search_with_attributes, name, val
          end),
          :greater_amount_recommended => (lambda do |search_with_attributes, request_params, name, val|
            val = val.first if val && val.is_a?(Array)
            if search_with_attributes[:amount_recommended_or_requested]
              search_with_attributes[:amount_recommended_or_requested] = (val.to_i..(search_with_attributes[:amount_recommended_or_requested].end))
            else
              search_with_attributes[:amount_recommended_or_requested] = (val.to_i..999999999999)
            end
            search_with_attributes
          end),
          :lesser_amount_recommended => (lambda do |search_with_attributes, request_params, name, val|
            val = val.first if val && val.is_a?(Array)
            if search_with_attributes[:amount_recommended_or_requested]
              search_with_attributes[:amount_recommended_or_requested] = ((search_with_attributes[:amount_recommended_or_requested].begin)..val.to_i)
            else
              search_with_attributes[:amount_recommended_or_requested] = (0..val.to_i)
            end
            search_with_attributes
          end),
          :request_from_date => (lambda do |search_with_attributes, request_params, name, val|
            val = val.first if val && val.is_a?(Array)
            date_range_selector = request_params[:request][:date_range_selector] if request_params[:request]
            date_range_selector = request_params[:date_range_selector] unless date_range_selector
            case date_range_selector
            when 'funding_agreement' then
              prepare_from_date search_with_attributes, :grant_agreement_at, val
            when 'grant_begins' then
              prepare_from_date search_with_attributes, :grant_begins_at, val
            when 'grant_ends' then
              prepare_from_date search_with_attributes, :grant_ends_at, val
            end
          end),
          :request_to_date => (lambda do |search_with_attributes, request_params, name, val|
            val = val.first if val && val.is_a?(Array)
            date_range_selector = request_params[:request][:date_range_selector] if request_params[:request]
            date_range_selector = request_params[:date_range_selector] unless date_range_selector
            case date_range_selector
            when 'funding_agreement' then
              prepare_to_date search_with_attributes, :grant_agreement_at, val
            when 'grant_begins' then
              prepare_to_date search_with_attributes, :grant_begins_at, val
            when 'grant_ends' then
              prepare_to_date search_with_attributes, :grant_ends_at, val
            end
          end)
        }
      
    end
    base.insta_realtime do |insta|
      insta.delta_attributes = SEARCH_ATTRIBUTES
      insta.updated_by_field = :updated_by_id
    end
    base.insta_json do |insta|
      insta.add_only 'base_request_id'
      insta.add_only 'amount_requested'
      insta.add_only 'amount_recommended'
      insta.add_only 'duration_in_months'
      insta.add_only 'granted'
      insta.add_only 'state'
      insta.add_only 'type'
      insta.add_only 'project_summary'
      insta.add_only 'request_received_at'
      insta.add_only 'grant_approved_at'
      insta.add_only 'grant_agreement_at'
      insta.add_only 'fip_projected_end_at'
      insta.add_only 'fip_title'
      insta.add_method 'title'
      insta.add_method 'program_name'
      insta.add_method 'sub_program_name'
      insta.add_method 'program_org_name'
      insta.add_method 'fiscal_org_name'
      insta.add_method 'program_lead_name'
      insta.add_method 'grantee_owner_name'
      insta.add_method 'fiscal_owner_name'
      insta.add_method 'grantee_signatory_name'
      insta.add_method 'fiscal_signatory_name'
      insta.add_method 'grant_or_request_id'
      insta.add_method 'grant_title'
      insta.add_method 'view_amount'
      
      insta.copy_style :simple, :detailed
      insta.add_method 'related_users', :detailed
      insta.add_method 'related_organizations', :detailed
      insta.add_method 'related_amendments', :detailed
      insta.add_method 'related_projects', :detailed
      insta.add_method 'related_request_reports', :detailed
      insta.add_method 'related_request_transactions', :detailed
      
    end
    

    
    base.insta_utc do |insta|
      insta.time_attributes = [:request_received_at, :grant_approved_at, :grant_agreement_at, :grant_amendment_at, :grant_begins_at, :grant_closed_at, :fip_projected_end_at, :ierf_proposed_end_at, :ierf_budget_end_at]
    end
    base.insta_filter_amount do |insta|
      insta.amount_attributes = [:amount_requested, :amount_recommended, :funds_expended_amount]
    end
    
    base.insta_formbuilder do |insta|
      insta.add_form_template :show, 'grantee_portal/create_new_portal_request', 'Grantee Portal Link to Create New Request'
    end
    
    base.insta_workflow do |insta|
      insta.add_state_to_english :new, 'New Request', 'new'
      insta.add_state_to_english :drafted, 'Draft', 'draft'
      insta.add_state_to_english :pending_grant_team_approval, 'Pending Grant Team Approval', 'approval'
      insta.add_state_to_english :pending_po_approval, 'Pending PO Approval', 'approval'
      insta.add_state_to_english :pending_president_approval, 'Pending President Approval', 'approval'
      insta.add_state_to_english :rejected, 'Rejected', 'rejected'
      insta.add_state_to_english :funding_recommended, 'Funding Recommended', ['edit_on_transition']
      insta.add_state_to_english :pending_grant_promotion, "Pending Grant/FIP Promotion", ['approval', 'pending_grant_promotion']
      insta.add_state_to_english :sent_back_to_pa, 'Sent back to PA', 'sent_back'
      insta.add_state_to_english :sent_back_to_po, 'Sent back to PO', 'sent_back'
      insta.add_state_to_english :granted, 'Granted', ['granted', 'become_grant']
      insta.add_state_to_english :closed, 'Closed', 'granted'
      insta.add_state_to_english :canceled, 'Canceled', ['granted', 'canceled']

      insta.add_event_to_english :submit_draft, 'Submit Draft'
      insta.add_event_to_english :recommend_funding, 'Recommend Funding'
      insta.add_event_to_english :complete_ierf, 'Mark IERF Completed'
      insta.add_event_to_english :grant_team_approve, 'Approve'
      insta.add_event_to_english :po_approve,  'Approve'
      insta.add_event_to_english :president_approve, 'Approve'
      insta.add_event_to_english :grant_team_send_back,  'Send Back'
      insta.add_event_to_english :po_send_back, 'Send Back'
      insta.add_event_to_english :president_send_back, 'Send Back'
      insta.add_event_to_english :reject,  'Reject'
      insta.add_event_to_english :un_reject, 'Un-Reject'
      insta.add_event_to_english :become_grant, 'Promote to Grant'
      insta.add_event_to_english :close_grant, 'Close'
      insta.add_event_to_english :fip_close_grant, 'Close'
      insta.add_event_to_english :cancel_grant, 'Cancel'        
      
      insta.add_non_validating_event :reject
      insta.add_non_validating_event :po_send_back
      insta.add_non_validating_event :president_send_back
      insta.add_non_validating_event :grant_team_send_back

      insta.on_enter_state_category('rejected', 'canceled') do |req|
        req.request_funding_sources.each(&:destroy)
      end
    end

    base.extend(ModelClassMethods)
    base.class_eval do
      include ModelInstanceMethods
    end

    base.add_aasm
    base.alias_method_chain :grantee_org_owner, :specific
    base.alias_method_chain :grantee_signatory, :specific
    base.alias_method_chain :fiscal_org_owner, :specific
    base.alias_method_chain :fiscal_signatory, :specific
    base.add_sphinx if base.respond_to?(:sphinx_indexes) && !(base.connection.adapter_name =~ /SQLite/i)

    # NOTE: for STI classes such as GrantRequest, the polymorphic associations must be replicated to get the correct class...
    base.has_many :workflow_events, :foreign_key => :workflowable_id, :conditions => ['workflowable_type in (?)', Request.request_class_names]
    base.has_many :favorites, :foreign_key => :favorable_id, :conditions => ['favorable_type in (?)', Request.request_class_names]
    base.has_many :notes, :foreign_key => :notable_id, :conditions => ['notable_type in (?)', Request.request_class_names]
    base.has_many :group_members, :foreign_key => :groupable_id, :conditions => ['groupable_type in (?)', Request.request_class_names]
  end

  module ModelClassMethods
    def request_class_names
      ['Request', 'GrantRequest', 'FipRequest']
    end
    
    def form_types
      type_list = []
      type_list << ['Grants', GrantRequest.name]
      type_list << [I18n.t(:fip_name).pluralize, FipRequest.name] unless Fluxx.config(:hide_fips) == "1"
      type_list
    end
    
    def add_aasm
      aasm_column :state
      aasm_initial_state :new

      aasm_state :new
      class_inheritable_reader :local_sent_back_state_mapping_to_workflow
      write_inheritable_attribute :local_sent_back_state_mapping_to_workflow, {:sent_back_to_pa => :funding_recommended, :sent_back_to_po => :pending_po_approval}
      
      def self.sent_back_state_mapping_to_workflow
        local_sent_back_state_mapping_to_workflow
      end

      def self.become_grant_event
        'become_grant'
      end
      

      [:sent_back_to_pa, :sent_back_to_po].each {|cur_state| aasm_state cur_state }

      aasm_state :pending_grant_team_approval
      aasm_state :pending_po_approval
      aasm_state :pending_president_approval
      aasm_state :pending_grant_promotion, :enter => :add_president_approval_date
      aasm_state :rejected
      aasm_state :funding_recommended
      aasm_state :new
      aasm_state :granted, :enter => :process_become_grant
      aasm_state :closed # Note that a user needs to close the grant.  The grants team would do this
      aasm_state :canceled # The grants team can cancel a grant after it has been granted
      aasm_state :drafted

      aasm_event :reject do
        (Request.all_states - Request.all_rejected_states).each do |cur_state|
          transitions :from => cur_state, :to => :rejected unless cur_state == :rejected
        end
      end

      aasm_event :un_reject do
        transitions :from => :rejected, :to => :new
      end

      aasm_event :submit_draft do
        transitions :from => :draft, :to => :new
      end

      aasm_event :recommend_funding do
        transitions :from => :new, :to => :funding_recommended
      end

      aasm_event :complete_ierf do
        transitions :from => :funding_recommended, :to => :pending_grant_team_approval
        transitions :from => :sent_back_to_pa, :to => :pending_grant_team_approval, :guard => (lambda { |req| !(req.has_grant_team_ever_approved?) })
        transitions :from => :sent_back_to_pa, :to => :pending_po_approval, :guard => (lambda { |req| req.has_grant_team_ever_approved? })
      end

      aasm_event :grant_team_approve do
        transitions :from => :pending_grant_team_approval, :to => :pending_po_approval
      end

      aasm_event :grant_team_send_back do
        transitions :from => :pending_grant_team_approval, :to => :sent_back_to_pa
      end

      aasm_event :po_approve do
        transitions :from => [:pending_po_approval, :sent_back_to_po], :to => :pending_president_approval
      end

      aasm_event :po_send_back do
        transitions :from => [:pending_po_approval, :sent_back_to_po], :to => :sent_back_to_pa
      end

      aasm_event :president_approve do
        transitions :from => :pending_president_approval, :to => :pending_grant_promotion
      end

      aasm_event :president_send_back do
        transitions :from => :pending_president_approval, :to => :sent_back_to_po
      end

      aasm_event :become_grant do
        transitions :from => :pending_grant_promotion, :to => :granted
      end

      aasm_event :close_grant do
        transitions :from => :granted, :to => :closed, :guard => (lambda {|req| req.is_a?(GrantRequest)})
      end

      aasm_event :fip_close_grant do
        transitions :from => :granted, :to => :closed, :guard => (lambda {|req| req.is_a?(FipRequest)})
      end

      aasm_event :cancel_grant do
        transitions :from => :granted, :to => :canceled
      end
    end
    
    def rejected_state_clause state_name
      result = if self.respond_to? :sphinx_rejected_state_clause
        self.sphinx_rejected_state_clause
      else
        if defined?(MachineState) && Request.column_names.include?('client_id')
          Request.send :sanitize_sql, ["IF(lower(requests.#{state_name}) in (select name from machine_states where machine_states.client_id = requests.client_id and state_type = ? and model_type in (?)), 1, 0)", MachineState.rejected_state_type_name, Request.descendant_base_classes.map(&:name)]
        else
          "IF(lower(requests.#{state_name}) = 'rejected', 1, 0)"
        end
      end
    end
    
    def add_sphinx
      
      # Allow the overriding of the state name and rewriting of the rejected clause
      state_name = if self.respond_to? :sphinx_state_name
        self.sphinx_state_name
      else
        'state'
      end
      include_model_theme_id = self.column_names.include?('model_theme_id')
      
      # Note!!!: across multiple indices, the structure must be the same or the index can get corrupted and attributes, search filter will not work properly
      define_index :request_first do
        # fields
        indexes "lower(requests.fip_title)", :as => :fip_title, :sortable => true
        indexes "CONCAT(IF(type = 'FipRequest', 'F-', 'R-'),base_request_id)", :sortable => true, :as => :request_id, :sortable => true
        indexes "lower(requests.project_summary)", :as => :project_summary, :sortable => true
        indexes :id, :sortable => true
        indexes "CONCAT(IF(type = 'FipRequest', 'FG-', 'G-'),base_request_id)", :sortable => true, :as => :grant_id, :sortable => true
        indexes :type, :sortable => true
        indexes program_organization.name, :as => :program_org_name, :sortable => true
        indexes program_organization.acronym, :as => :program_org_acronym, :sortable => true
        indexes FluxxGrantSphinxHelper.generate_parent_program_acronym('requests'), :sortable => true, :as => :parent_program_acronym, :sortable => true
        indexes fiscal_organization.name, :as => :fiscal_org_name, :sortable => true
        indexes fiscal_organization.acronym, :as => :fiscal_org_acronym, :sortable => true
        indexes FluxxGrantSphinxHelper.generate_parent_fiscal_acronym('requests'), :sortable => true, :as => :parent_fiscal_acronym, :sortable => true
        indexes program.name, :as => :program_name, :sortable => true

        # attributes
        has :created_at, :updated_at, :deleted_at, :created_by_id, :program_id, :sub_program_id, :request_received_at, :grant_agreement_at, :grant_begins_at, :granted
        has "CAST(skip_hgrant_flag AS UNSIGNED INT)", :type => :boolean, :as => :skip_hgrant_flag
        has :program_organization_id, :fiscal_organization_id
        has "if(requests.amount_recommended is null, ROUND(requests.amount_requested), ROUND(requests.amount_recommended))", :as => :amount_recommended_or_requested, :type => :integer
        has "ROUND(requests.amount_recommended)", :as => :amount_recommended, :type => :integer
        has "ROUND(requests.amount_requested)", :as => :amount_requested, :type => :integer
        has "if(granted = 0, (CONCAT(IFNULL(`program_organization_id`, '0'), ',', IFNULL(`fiscal_organization_id`, '0'))), null)", 
          :as => :related_request_organization_ids, :type => :multi
        has "if(granted = 1, (CONCAT(IFNULL(`program_organization_id`, '0'), ',', IFNULL(`fiscal_organization_id`, '0'))), null)", 
          :as => :related_grant_organization_ids, :type => :multi
        has "IF(requests.base_request_id IS NULL, 1, 0)", :as => :missing_request_id, :type => :boolean
        has "if(duration_in_months is not null, date_add(date_add(grant_begins_at, interval duration_in_months MONTH), interval -1 DAY), if(fip_projected_end_at is not null, fip_projected_end_at, grant_closed_at))", :as => :grant_ends_at, :type => :datetime
        has Request.rejected_state_clause(state_name), :as => :has_been_rejected, :type => :boolean

        has :type, :type => :string, :crc => true, :as => :filter_type
        has :base_request_id, :type => :string, :crc => true, :as => :base_request_id
        has "requests.#{state_name}", :type => :string, :crc => true, :as => :filter_state
        has program_lead(:id), :type => :multi, :as => :lead_user_ids

        has "null", :type => :multi, :as => :org_owner_user_ids
        has "null", :type => :multi, :as => :favorite_user_ids
        has "concat(program_lead_id, ',', IFNULL(grantee_org_owner_id, '0'), ',', IFNULL(grantee_signatory_id, '0'), ',', IFNULL(fiscal_org_owner_id, '0'), ',', IFNULL(fiscal_signatory_id, '0'))", :type => :multi, :as => :user_ids
        
        has "null", :type => :multi, :as => :raw_request_org_ids

        has "null", :type => :multi, :as => :request_org_ids
        has "null", :type => :multi, :as => :grant_org_ids
        has "null", :type => :multi, :as => :request_user_ids
        has "null", :type => :multi, :as => :funding_source_ids

        has "null", :type => :multi, :as => :group_ids
        has request_programs.program(:id), :type => :multi, :as => :request_program_ids
        has "CONCAT(requests.program_id, CONCAT(',', GROUP_CONCAT(DISTINCT IFNULL(`request_programs`.`program_id`, '0') SEPARATOR ',')))", :type => :multi, :as => :all_request_program_ids
        has "CONCAT(program_organization_id, ',', fiscal_organization_id)", :type => :multi, :as => :program_or_fiscal_org_ids
        has multi_element_choices.multi_element_value(:id), :type => :multi, :as => :multi_element_value_ids
        has FluxxGrantSphinxHelper.funding_source_allocation_program('requests'), :type => :multi, :as => :funding_source_allocation_program_id
        has FluxxGrantSphinxHelper.funding_source_allocation_sub_program_id('requests'), :type => :multi, :as => :funding_source_allocation_sub_program_id
      	has FluxxGrantSphinxHelper.funding_source_allocation_initiative_id('requests'), :type => :multi, :as => :funding_source_allocation_initiative_id
        has "funding_source_allocations.sub_initiative_id", :type => :multi, :as => :funding_source_allocation_sub_initiative_id
        has request_funding_sources.funding_source_allocation(:id), :type => :multi, :as => :funding_source_allocation_id
        
        has FluxxGrantSphinxHelper.request_hierarchy, :type => :multi, :as => :request_hierarchy
        has FluxxGrantSphinxHelper.allocation_hierarchy('requests'), :type => :multi, :as => :allocation_hierarchy
            
        has model_theme_id if include_model_theme_id
        set_property :delta => :delayed
      end

      define_index :request_second do
        indexes "lower(requests.fip_title)", :as => :fip_title, :sortable => true
        indexes 'null', :sortable => true, :as => :request_id, :sortable => true
        indexes :project_summary, :sortable => true
        indexes :id, :sortable => true
        indexes 'null', :sortable => true, :as => :grant_id, :sortable => true
        indexes :type, :sortable => true
        indexes program_organization.name, :as => :program_org_name, :sortable => true
        indexes program_organization.acronym, :as => :program_org_acronym, :sortable => true
        indexes FluxxGrantSphinxHelper.generate_parent_program_acronym('requests'), :sortable => true, :as => :parent_program_acronym, :sortable => true
        indexes fiscal_organization.name, :as => :fiscal_org_name, :sortable => true
        indexes fiscal_organization.acronym, :as => :fiscal_org_acronym, :sortable => true
        indexes FluxxGrantSphinxHelper.generate_parent_fiscal_acronym('requests'), :sortable => true, :as => :parent_fiscal_acronym, :sortable => true
        indexes program.name, :as => :program_name, :sortable => true

        # attributes
        has :created_at, :updated_at, :deleted_at, :created_by_id, :program_id, :sub_program_id, :request_received_at, :grant_agreement_at, :grant_begins_at, :granted
        has "CAST(skip_hgrant_flag AS UNSIGNED INT)", :type => :boolean, :as => :skip_hgrant_flag
        has :program_organization_id, :fiscal_organization_id
        has "if(requests.amount_recommended is null, ROUND(requests.amount_requested), ROUND(requests.amount_recommended))", :as => :amount_recommended_or_requested, :type => :integer
        has "ROUND(requests.amount_recommended)", :as => :amount_recommended, :type => :integer
        has "ROUND(requests.amount_requested)", :as => :amount_requested, :type => :integer
        has "null", :as => :related_request_organization_ids, :type => :multi
        has "null", :as => :related_grant_organization_ids, :type => :multi
        has "IF(requests.base_request_id IS NULL, 1, 0)", :as => :missing_request_id, :type => :boolean
        has "if(duration_in_months is not null, date_add(date_add(grant_begins_at, interval duration_in_months MONTH), interval -1 DAY), if(fip_projected_end_at is not null, fip_projected_end_at, grant_closed_at))", :as => :grant_ends_at, :type => :datetime
        has Request.rejected_state_clause(state_name), :as => :has_been_rejected, :type => :boolean

        has :type, :type => :string, :crc => true, :as => :filter_type
        has :base_request_id, :type => :string, :crc => true, :as => :base_request_id
        has "requests.#{state_name}", :type => :string, :crc => true, :as => :filter_state
        has "null", :type => :multi, :as => :lead_user_ids

        has grantee_org_owner(:id), :type => :multi, :as => :org_owner_user_ids
        has "null", :type => :multi, :as => :favorite_user_ids
        has "null", :type => :multi, :as => :user_ids
        has "null", :type => :multi, :as => :raw_request_org_ids

        has "null", :type => :multi, :as => :request_org_ids
        has "null", :type => :multi, :as => :grant_org_ids
        has request_users(:id), :type => :multi, :as => :request_user_ids
        has request_funding_sources.funding_source_allocation.funding_source(:id), :type => :multi, :as => :funding_source_ids

        has "null", :type => :multi, :as => :group_ids
        has "null", :type => :multi, :as => :request_program_ids
        has "null", :type => :multi, :as => :all_request_program_ids
        has "CONCAT(program_organization_id, ',', fiscal_organization_id)", :type => :multi, :as => :program_or_fiscal_org_ids
        has "null", :type => :multi, :as => :multi_element_value_ids

        # NOTE ESH: this is very simmilar to the fluxx_funding_source_allocation.rb build_temp_table method
        has FluxxGrantSphinxHelper.funding_source_allocation_program('requests'), :type => :multi, :as => :funding_source_allocation_program_id
        has FluxxGrantSphinxHelper.funding_source_allocation_sub_program_id('requests'), :type => :multi, :as => :funding_source_allocation_sub_program_id
      	has FluxxGrantSphinxHelper.funding_source_allocation_initiative_id('requests'), :type => :multi, :as => :funding_source_allocation_initiative_id
        has "funding_source_allocations.sub_initiative_id", :type => :multi, :as => :funding_source_allocation_sub_initiative_id
        has request_funding_sources.funding_source_allocation(:id), :type => :multi, :as => :funding_source_allocation_id
        has FluxxGrantSphinxHelper.request_hierarchy, :type => :multi, :as => :request_hierarchy
        
        has FluxxGrantSphinxHelper.allocation_hierarchy('requests'), :type => :multi, :as => :allocation_hierarchy
        

        has model_theme_id if include_model_theme_id
        set_property :delta => :delayed
      end

      define_index :request_third do
        indexes "lower(requests.fip_title)", :as => :fip_title, :sortable => true
        indexes 'null', :sortable => true, :as => :request_id, :sortable => true
        indexes :project_summary, :sortable => true
        indexes :id, :sortable => true
        indexes 'null', :sortable => true, :as => :grant_id, :sortable => true
        indexes :type, :sortable => true
        indexes program_organization.name, :as => :program_org_name, :sortable => true
        indexes program_organization.acronym, :as => :program_org_acronym, :sortable => true
        indexes FluxxGrantSphinxHelper.generate_parent_program_acronym('requests'), :sortable => true, :as => :parent_program_acronym, :sortable => true
        indexes fiscal_organization.name, :as => :fiscal_org_name, :sortable => true
        indexes fiscal_organization.acronym, :as => :fiscal_org_acronym, :sortable => true
        indexes FluxxGrantSphinxHelper.generate_parent_fiscal_acronym('requests'), :sortable => true, :as => :parent_fiscal_acronym, :sortable => true
        indexes program.name, :as => :program_name, :sortable => true

        # attributes
        has :created_at, :updated_at, :deleted_at, :created_by_id, :program_id, :sub_program_id, :request_received_at, :grant_agreement_at, :grant_begins_at, :granted
        has "CAST(skip_hgrant_flag AS UNSIGNED INT)", :type => :boolean, :as => :skip_hgrant_flag
        has :program_organization_id, :fiscal_organization_id
        has "if(requests.amount_recommended is null, ROUND(requests.amount_requested), ROUND(requests.amount_recommended))", :as => :amount_recommended_or_requested, :type => :integer
        has "ROUND(requests.amount_recommended)", :as => :amount_recommended, :type => :integer
        has "ROUND(requests.amount_requested)", :as => :amount_requested, :type => :integer
        has "null", :as => :related_request_organization_ids, :type => :multi
        has "null", :as => :related_grant_organization_ids, :type => :multi
        has "IF(requests.base_request_id IS NULL, 1, 0)", :as => :missing_request_id, :type => :boolean
        has "if(duration_in_months is not null, date_add(date_add(grant_begins_at, interval duration_in_months MONTH), interval -1 DAY), if(fip_projected_end_at is not null, fip_projected_end_at, grant_closed_at))", :as => :grant_ends_at, :type => :datetime
        has Request.rejected_state_clause(state_name), :as => :has_been_rejected, :type => :boolean

        has :type, :type => :string, :crc => true, :as => :filter_type
        has :base_request_id, :type => :string, :crc => true, :as => :base_request_id
        has "requests.#{state_name}", :type => :string, :crc => true, :as => :filter_state
        has "null", :type => :multi, :as => :lead_user_ids

        has "null", :type => :multi, :as => :org_owner_user_ids
        has favorites.user(:id), :type => :multi, :as => :favorite_user_ids
        has "null", :type => :multi, :as => :user_ids
        has request_organizations.organization(:id), :type => :multi, :as => :raw_request_org_ids
        has "GROUP_CONCAT(DISTINCT if(granted = 0, IFNULL(`organizations_request_organizations`.`id`, '0'), null) SEPARATOR ',')", :type => :multi, :as => :request_org_ids
        has "GROUP_CONCAT(DISTINCT if(granted = 1, IFNULL(`organizations_request_organizations`.`id`, '0'), null) SEPARATOR ',')", :type => :multi, :as => :grant_org_ids
        has "null", :type => :multi, :as => :request_user_ids
        has "null", :type => :multi, :as => :funding_source_ids

        has group_members.group(:id), :type => :multi, :as => :group_ids
        has "null", :type => :multi, :as => :request_program_ids
        has "null", :type => :multi, :as => :all_request_program_ids
        has "CONCAT(program_organization_id, ',', fiscal_organization_id)", :type => :multi, :as => :program_or_fiscal_org_ids
        has "null", :type => :multi, :as => :multi_element_value_ids
        has FluxxGrantSphinxHelper.funding_source_allocation_program('requests'), :type => :multi, :as => :funding_source_allocation_program_id
        has FluxxGrantSphinxHelper.funding_source_allocation_sub_program_id('requests'), :type => :multi, :as => :funding_source_allocation_sub_program_id
      	has FluxxGrantSphinxHelper.funding_source_allocation_initiative_id('requests'), :type => :multi, :as => :funding_source_allocation_initiative_id
        has "funding_source_allocations.sub_initiative_id", :type => :multi, :as => :funding_source_allocation_sub_initiative_id
        has request_funding_sources.funding_source_allocation(:id), :type => :multi, :as => :funding_source_allocation_id
        has FluxxGrantSphinxHelper.request_hierarchy, :type => :multi, :as => :request_hierarchy
        has FluxxGrantSphinxHelper.allocation_hierarchy('requests'), :type => :multi, :as => :allocation_hierarchy
       
        has model_theme_id if include_model_theme_id
        set_property :delta => :delayed
      end
    end
    
    def document_title_name
      'Request'
    end
    
    def translate_grant_type type
      case type
        when 'GrantRequest'
          'Grants'
        when 'FipRequest'
          I18n.t(:fip_name)
      end
    end
    
    # Often need to prepare a SQL condition requests.type in (GrantRequest, FipRequest), etc.  This makes it easier to do so
    def prepare_request_types_for_where_clause request_types
      request_types = [request_types] if request_types.is_a?(String)
      request_type_clause = if (request_types && request_types.is_a?(Array) && !request_types.empty?)
        quoted_rts = request_types.map{|rt| "'#{rt}'"}
        "AND requests.type in (#{quoted_rts.join(',')})"
      end || ""
    end
  end

  module ModelInstanceMethods
    attr_accessor :amend
    attr_accessor :amend_note
    alias_method :amend?, :amend

    def validate_funding_sources
      missing_funding_sources = ['(at least one Funding Source is required)'] if request_funding_sources.empty?
      errors[:Missing_funding_sources] << missing_funding_sources if missing_funding_sources
      missing_funding_sources
    end

    def validate_if_past_state_or_should_validate validate_state
      (should_validate? && state == validate_state) || state_past(Request.all_workflow_states, validate_state, state)
    end

    def validate_if_in_or_past_state validate_state
      state.to_sym==validate_state.to_sym || state_past((Request.all_workflow_states), validate_state, state)
    end
    
    def should_validate?
      promotion_event==true && !self.new_record?
    end
    
    def grant_ends_at
      (duration_in_months && grant_begins_at) ? (grant_begins_at + duration_in_months.month - 1.day) : grant_begins_at
    end

    def process_before_save_blocks
      if self.before_save_blocks
        self.before_save_blocks.each {|block| block.call(self)}
      end
    end

    def add_before_save_block block
      self.before_save_blocks ||= []
      self.before_save_blocks << block
    end

    # Force the sphinx indices to be updated
    def update_related_data
      if Request.respond_to? :indexed_by_sphinx?
        User.without_realtime do
          us = related_users.map(&:id)
          User.update_all 'delta = 1', ['id in (?)', us]
          unless us.empty?
            u = User.find(us.first)
            u.delta = 1
            u.save 
          end
        end
        Organization.without_realtime do
          orgs = []
          orgs << program_organization.id if program_organization
          orgs << fiscal_organization.id if fiscal_organization
          Organization.update_all 'delta = 1', ['id in (?)', orgs]
          unless orgs.empty?
            o = Organization.find(orgs.first)
            o.delta = 1
            o.save 
          end
        end
        RequestTransaction.without_realtime do
          rts = request_transactions.map(&:id)
          RequestTransaction.update_all 'delta = 1', ['id in (?)', rts]
          unless rts.empty?
            rt = RequestTransaction.find(rts.first)
            rt.delta = 1
            rt.save 
          end
        end
        RequestReport.without_realtime do
          reps = request_reports.map(&:id)
          RequestReport.update_all 'delta = 1', ['id in (?)', reps]
          unless reps.empty?
            rep = RequestReport.find(reps.first)
            rep.delta = 1
            rep.save 
          end
        end
      end
    end

    def tax_class_org
      fiscal_organization ? fiscal_organization : program_organization
    end

    def has_tax_class?
      tax_class_org ? tax_class_org.tax_class_id : nil
    end

    def is_er?
      tax_class_org ? tax_class_org.is_er? : nil
    end

    def is_grant?
      self.granted
    end

    def amount_funded
      paid_states = RequestTransaction.all_states_with_category('paid').map{|st| st.to_s}
      amount_paids = request_transactions.select{|rt| paid_states.include?(rt.state)}.map(&:amount_paid).compact
      amount_paids.sum if !amount_paids.empty?
    end

    def amount_pending
      paid_states = RequestTransaction.all_states_with_category('paid').map{|st| st.to_s}
      amount_due = request_transactions.reject{|rt| paid_states.include?(rt.state)}.map(&:amount_due).compact
      amount_due.sum if !amount_due.empty?
    end

    def to_s
      title
    end

    def title
      "#{tax_class_org ? tax_class_org.name : ''} #{self.granted ? grant_id : request_id} #{(amount_recommended || amount_requested || 0).to_currency(:precision => 2)}"
    end

    ## Letter specific helpers
    def fiscal_or_program_possessive
      if fiscal_organization && fiscal_organization != program_organization
        "#{fiscal_organization.name}'s"
      else
        'your'
      end
    end
    
    def program_name
      program.name if program
    end

    def sub_program_name
      sub_program.name if sub_program
    end
    
    def program_org_name
      program_organization.name if program_organization
    end

    def fiscal_org_name
      fiscal_organization.name if fiscal_organization
    end
    
    def program_lead_name
      program_lead.full_name if program_lead
    end
    
    def grantee_owner_name
      grantee_org_owner.full_name if grantee_org_owner
    end
    
    def fiscal_owner_name
      fiscal_org_owner.full_name if fiscal_org_owner
    end
    
    def grantee_signatory_name
      grantee_signatory.full_name if grantee_signatory
    end
    
    def fiscal_signatory_name
      fiscal_signatory.full_name if fiscal_signatory
    end
    
    def proposal_date_text
      proposal_date = if ierf_proposed_end_at
        ierf_proposed_end_at.full 
      elsif request_received_at
        request_received_at.full 
      end
      "#{proposal_date} proposal and budget"
    end

    def generate_request_id
      current_time = Time.now
      self.update_attributes :request_received_at => current_time,
        :base_request_id => (current_time.strftime("%y%m-") + id.to_s.rjust(5, '0'))  # Generate the request ID
      self.save(:validate => false)
    end

    def request_id
      "#{request_prefix}-#{base_request_id}" if base_request_id
    end

    def grant_id
      "#{grant_prefix}-#{base_request_id}" if self.granted && base_request_id
    end
    
    def display_id
      if granted
        grant_id
      else
        request_id
      end
    end
      
    def grant_or_request_id
      is_grant? ? grant_id : request_id
    end

    def view_amount
      self.granted ? self.amount_recommended : self.amount_requested
    end
    
    def grant_title
      if self.is_a? FipRequest
        self.fip_title
      else
        self.org_name_text
      end
    end

    def generate_grant_dates
      self.grant_agreement_at = Time.now
      self.granted = true
      self.grant_begins_at = Time.parse((grant_agreement_at + 1.month).strftime('%Y/%m/1')).next_business_day unless grant_begins_at
    end
    
    # This is a method meant to be run on requests that are currently in pending_secondary_pd_approval state
    # It figures out when it was switched to pending secondary approval, and if it's more than 5 days, it will promote it automatically
    def check_for_secondary_promotion
      pending_secondary_pd_approval_state = Request.all_states_with_category('pending_secondary_pd_approval').first
      
      if pending_secondary_pd_approval_state
        we = workflow_events.find :first, :conditions => {:new_state => pending_secondary_pd_approval_state.to_s}, :order => 'id desc'
        if we.created_at < (Time.now - 7.days)
          # Time to promote this puppy!!
          pending_request_programs = request_programs.select{|rp| !rp.is_approved? }
          unless pending_request_programs.empty?
            RequestProgram.without_workflow do
              pending_request_programs.each{|rp| rp.skip_request_approval=true; rp.approve}
            end
          end
          if self.state == pending_secondary_pd_approval_state.to_s
            self.workflow_note = '7 Day Approval Limit Expired'
            self.secondary_pd_approve
          end
          self.save
        end
      end
    end
    

    def request_prefix
      'R'
    end

    def grant_prefix
      'G'
    end

    def filter_state
      self.state
    end

    def filter_type
      self.type
    end

    def lead_user_ids
      program_lead ? program_lead.id : nil
    end
    
    def request_hierarchy
      "#{program_id}-#{sub_program_id}-#{initiative_id}-#{sub_initiative_id}"
    end
    
    def allocation_hierarchy
      request_funding_sources.map do |rfs|
        "#{rfs.program_id}-#{rfs.sub_program_id}-#{rfs.initiative_id}-#{rfs.sub_initiative_id}"
      end
    end
    
    # OK, this is a bit bogus, but we don't have a definitive association between a request and a board authority year; this is really the best we can do
    def board_authority_year
      begin
        request_funding_sources.first.funding_source_allocation.funding_source_allocation_authorities.first.authority if request_funding_sources && 
           request_funding_sources.first &&
           request_funding_sources.first.funding_source_allocation &&
           request_funding_sources.first.funding_source_allocation.funding_source_allocation_authorities &&
           request_funding_sources.first.funding_source_allocation.funding_source_allocation_authorities.first 
      rescue Exception => e
      end
    end
    
    def request_received_at_year
      request_received_at.year if request_received_at
    end

    def org_owner_user_ids
      grantee_org_owner ? grantee_org_owner.id : nil
    end
    
    def related_users
      (request_users.map{|ru| ru.user} + [program_lead, grantee_org_owner, grantee_signatory, fiscal_org_owner, fiscal_signatory]).compact.reject{|u| u.deleted_at}.sort_by{|u| [u.last_name || '', u.first_name || '']}
    end
    
    def related_organizations
      (request_organizations.joins(:organization).where(:organizations => {:deleted_at => nil}).order(:name).map{|ro| ro.organization} + [program_organization, fiscal_organization]).compact.reject{|o| o.deleted_at}
    end
    
    def related_request_reviews
      query = request_reviews.where('rating is not null').where(:conflict_reported => nil)
      average_rating = query.select('avg(rating) average_rating').first
      average_rating = average_rating.average_rating if average_rating
      all_ratings = query.all
      [average_rating, all_ratings].flatten
    end
    
    def related_projects limit_amount=50
      projects.order('projects.created_at desc').limit(limit_amount)
    end

    def related_request_transactions limit_amount=50
      request_transactions.where(:deleted_at => nil).order('due_at desc').limit(limit_amount)
    end

    def related_request_reports limit_amount=50
      # (current_user.is_board_member? ? request_reports.where(:state => "approved") : request_reports).where(:deleted_at => nil).order('due_at desc').limit(limit_amount)
      (request_reports).where(:deleted_at => nil).order('due_at desc').limit(limit_amount)
    end
    
    def related_amendments limit_amount=50
      request_amendments.where(:original => 0).order('id desc').limit(limit_amount)
    end
    
    def letter_project_summary
      request_project_summary = project_summary || ''
      request_project_summary = request_project_summary.strip
      request_project_summary = request_project_summary.gsub /\.$/, ''
      request_project_summary = request_project_summary.first.downcase + request_project_summary[1..request_project_summary.size]
    end

    def letter_project_summary_without_leading_to
      request_project_summary = letter_project_summary || ''
      request_project_summary.gsub /^To/i, ''
    end
    
    def first_transaction
      request_transactions.order(:due_at).first
    end

    # Make the delta type 
    def realtime_classname
      # NOTE: this logic also exists in fluxx_common_requests_controller.rb, we need to keep these two in sync!!!
      'Request' + (self.granted ? 'Granted' : 'NotYetGranted')
    end
    
    def add_president_approval_date
      self.grant_approved_at = Time.now
    end

    def process_become_grant
      self.granted = true
    end

    def has_grant_team_ever_approved?
      !(workflow_events.select do |event| 
        (event.old_state == 'pending_grant_team_approval' && event.new_state == 'pending_po_approval')
      end.empty?)
    end
    
    def grantee_org_owner_with_specific
      if program_organization
        grantee_org_owner_without_specific
      end
    end
    def grantee_signatory_with_specific
      if program_organization
        grantee_signatory_without_specific
      end
    end
    def fiscal_org_owner_with_specific
      if fiscal_organization
        fiscal_org_owner_without_specific
      end
    end
    def fiscal_sponsor_org
      fiscal_organization
    end
    def fiscal_signatory_with_specific
      if fiscal_organization
        fiscal_signatory_without_specific
      end
    end
    
    def state_after_pre_recommended_chain
      state && (amend? || !(in_draft_state? || in_new_state? || in_reject_state? || granted? || closed?))
    end

    def signatory_contact
      fiscal_signatory  || fiscal_org_owner || grantee_signatory ||  grantee_org_owner || User.new
    end
    
    def signatory_user_org
      return nil if signatory_contact.nil? || address_org.nil?
      signatory_contact.user_organizations.where(:organization_id => address_org.id).first
    end
    
    def signatory_contact_title
      signatory_user_org_title
    end
    
    def signatory_user_org_title
      signatory_user_org ? signatory_user_org.title : nil
    end  
    
    def address_org
      fiscal_organization || program_organization || Organization.new
    end
    
    def all_request_programs_approved? program=nil
      return running_timeline if running_timeline # for event_timeline purposes
      checking_programs = if program
        request_programs.reject{|rp| rp.program == program}
      else
        request_programs
      end
      result = checking_programs.select {|rp| !rp.is_approved?}.empty?
      result
    end
    
    # Mark related classes that show up in searches as deleted
    def handle_cascading_deletes
      if self.deleted_at
        user = User.find(updated_by_id) if updated_by_id
        request_reports.each {|rep| rep.safe_delete(user) rescue nil}
        request_transactions.each {|trans| trans.safe_delete(user) rescue nil}
        request_funding_sources.each {|rfs| rfs.safe_delete(user) rescue nil}
      end
    end
    
    def original_amount_recommended
      if self.request_amendments && !self.request_amendments.empty?
        amendments = self.request_amendments.select {|amend| amend.amount_recommended && amend.original?}
        amendments && !amendments.empty? ? amendments.first.amount_recommended : self.amount_recommended
      elsif amount_recommended_changed?
        changed_attributes['amount_recommended']
      else
        amount_recommended
      end
    end
    
    attr_accessor :skip_amendments
    def build_amendment
      if amend? && !skip_amendments
        if request_amendments.empty?
          # Create the original amendment
          a = request_amendments.build()
          a[:duration] = changed_attributes['duration_in_months'] || duration_in_months
          a[:start_date] = changed_attributes['grant_begins_at'] || grant_begins_at
          if self.is_a?(FipRequest)
            a[:end_date] = changed_attributes['fip_projected_end_at'] || fip_projected_end_at
          else
            a[:end_date] = changed_attributes['grant_closed_at'] || grant_closed_at
          end
          a[:amount_recommended] = changed_attributes['amount_recommended'] || amount_recommended
          a[:original] = true
        end
        a = request_amendments.build()
        a[:duration] = duration_in_months if duration_in_months_changed?
        a[:old_duration] = changed_attributes['duration_in_months'] || duration_in_months
        a[:start_date] = grant_begins_at if grant_begins_at_changed?
        a[:old_start_date] = changed_attributes['grant_begins_at'] || grant_begins_at
        if self.is_a?(FipRequest)
          a[:end_date] = fip_projected_end_at if fip_projected_end_at_changed?
          a[:old_end_date] = changed_attributes['fip_projected_end_at'] || fip_projected_end_at
        else
          a[:end_date] = grant_closed_at if grant_closed_at_changed?
          a[:old_end_date] = changed_attributes['grant_closed_at'] || grant_closed_at
        end
        if amount_recommended_changed?
          a[:amount_recommended] = amount_recommended
        end
        a[:old_amount_recommended] = changed_attributes['amount_recommended'] || amount_recommended
        a[:original] = false

        append_amendment_note
        a[:note] = amend_note
      end

      true # stop touching meee!
    end
    
    def find_new_amendment
      amendments = self.request_amendments.select{|amend| !amend.original && amend.new_record?}
      amendments && amendments.first
    end

    def append_amendment_note
      p "ESH: 111aaabbb in append_amendment_note in fluxx_request"
      note = []
      note << "Amount amended from #{amount_recommended_was ? amount_recommended_was.to_currency : ''} to #{amount_recommended ? amount_recommended.to_currency : ''}." if amount_recommended_changed?
      note << "Duration amended from #{duration_in_months_was} to #{duration_in_months}." if duration_in_months_changed?
      note << "Start Date amended from #{grant_begins_at_was ? grant_begins_at_was.mdy : ''} to #{grant_begins_at ? grant_begins_at.mdy : ''}." if grant_begins_at_changed?
      note << "End Date amended from #{fip_projected_end_at_was ? fip_projected_end_at_was.mdy : ''} to #{fip_projected_end_at ? fip_projected_end_at.mdy : ''}." if fip_projected_end_at_changed?
      note << amend_note unless amend_note.to_s.empty?
      note_text = note.join(" ")
      notes.build(:note => note_text, :created_by => self.updated_by, :updated_by => self.updated_by)
      note_text
    end
    
    # Deal with wonky behavior of secondary request programs
    def fire_event_override event_name, user
      result = if user && Request.all_states_with_category('pending_secondary_pd_approval').include?(state.to_sym)
        self.request_programs.each do |rp|
          # TODO ESH: consider adding categories to roles to be able to identify the program directory role; otherwise we rely on naming conventions for the roles.  Programme director would screw everything up for example
          if !rp.is_approved? && user.has_role?(Program.program_director_role_name, rp.program)
            rp.request = self # Make sure that this request_program doesn't load up a different request since we might be changing its state (don't want to change it in two places since the save will happen on this instance of request)
            rp.updated_by = user
            rp.workflow_note = self.workflow_note
            rp.approve
            rp.save
          end
        end
        # self.save # May have switched state in the request; save to be sure
        # p "ESH: have errors = #{self.errors.inspect}"
        true # Do not try to fire the regular event
      end
    end

    def funding_sources_expired_before_close_date
      if (end_date = fip_projected_end_at || grant_closed_at || grant_ends_at)
        expiring_fund_sources = request_funding_sources.map do |rfs|
          rfs.funding_source_allocation.funding_source.name if rfs.funding_source_allocation && rfs.funding_source_allocation.funding_source.end_at && rfs.funding_source_allocation.funding_source.end_at < end_date
        end.compact
        
        expiring_fund_sources.empty? ? nil : expiring_fund_sources.join(', ')
      end
    end

    def duration_over_12_months?
      duration_in_months > 12 if duration_in_months
    end
    
    def is_marked_complete?
      Request.all_states_with_category('approval').include?(state && !state.empty? ? state.to_sym: nil) || granted
    end

    def funding_warnings
      unless @funding_warnings
        @funding_warnings = []

        if Organization.charity_check_enabled && tax_class_org && !tax_class_org.has_c3_status_approved?
          @funding_warnings << 'No c3 status'
        elsif duration_over_12_months?
          @funding_warnings << 'Duration is over 12 months' 

          if fs = funding_sources_expired_before_close_date
            @funding_warnings << "Funding source(s) #{fs} expire before the estimated grant close date" 
          end
        end
      end

      @funding_warnings
    end

    def general_warnings
      unless @warnings
        @general_warnings = []
        @general_warnings << 'This grant is funding general operating support.' if funding_general_operating_support 
        @general_warnings << 'This grant requires direct board authority.' if board_authorization_required 
        @general_warnings << 'This grant is a renewal.' if renewal_grant
        @general_warnings
      end
      @general_warnings
    end
    
    def promotion_warnings
      unless @promotion_warnings 
        @promotion_warnings = []
        request_funding_sources.each do |rfs|
          if rfs.funding_source_allocation && rfs.funding_amount && !(rfs.funding_amount <= rfs.funding_source_allocation.amount_remaining)
            @promotion_warnings << I18n.t(:insufficient_funds_in_allocation, :allocation_name => (rfs.funding_source_allocation.funding_source ? rfs.funding_source_allocation.funding_source.name : 'Unnamed Funding Source')) 
          end
        end
      end
      @promotion_warnings
    end

    # validate both GrantRequest and Organization docs
    def validate_required_docs
      req_docs = required_request_docs
      org_docs = required_organization_docs
      missing  = req_docs.find_all {|d| !model_documents.collect(&:model_document_type_id).include? d.id }
      missing += org_docs.find_all {|d| !program_organization.model_documents.collect(&:model_document_type_id).include? d.id } if program_organization
      errors[:missing_documents] << missing.map(&:name).join(', ') unless missing.empty?
    end

    # this method is used both above and in the view to show required docs
    def required_request_docs
      ModelDocumentType.where(:model_type => model_type, :required => true).where(['if(program_id is not null, program_id = ?, true) AND 
        if(sub_program_id is not null, program_id = ?, true) AND 
          if(initiative_id is not null, initiative_id = ?, true) AND 
            if(sub_initiative_id is not null, initiative_id = ?, true)',self.program_id, self.sub_program_id, self.initiative_id, self.sub_initiative_id]).all
    end

    def required_organization_docs
      ModelDocumentType.where(:model_type => Organization.name, :required => true).all
    end
    
    def update_warnings_note
      if changed_attributes.include?('display_warnings') && !self.display_warnings
        note = Note.create(:created_by_id => self.updated_by_id, :updated_by_id => self.updated_by_id, :note => "Turned off the following warnings: '#{self.funding_warnings}'", :notable_id => self.id, :notable_type => self.class.name) 
      end
    end

    def funds_expended
      expended = ""
      if funds_expended_amount
        expended = as_currency(funds_expended_amount)
        expended += "on #{model.funds_expended_at.mdy}" if funds_expended_at
      end
      expended
    end
    
    # If this has been granted already, only show amount recommended.  Otherwise show either amount recommended or amount requested
    def display_amount
      granted ? amount_recommended : (amount_recommended || amount_requested)
    end

    def created_by_with_create_date
      "#{created_by.full_name if created_by} (#{created_at.mdy if created_at})"
    end
    
    def as_json(options = nil)
      super((options || {}).merge(:root => 'request'))
    end
    
    def initial_payment
      request_transactions.first || RequestTransaction.new
    end
    def interim_payment
      (request_transactions.size > 2) ? request_transactions[1] : nil
    end
    def final_payment
      request_transactions.last || RequestTransaction.new
    end

    def initial_report
      letter_request_reports.first || RequestReport.new 
    end
    def final_report
      letter_request_reports.size > 1 ? letter_request_reports.last : RequestReport.new
    end

    def funding_source_list
      request_funding_sources.map{|rfs| rfs.funding_source_allocation.funding_source.name if rfs.funding_source_allocation && rfs.funding_source_allocation.funding_source}.join(',')
    end
    
  end
end
