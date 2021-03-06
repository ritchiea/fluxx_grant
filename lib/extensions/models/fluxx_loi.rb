module FluxxLoi
  attr_accessor :request_note
  attr_accessor :request_attributes

  SEARCH_ATTRIBUTES = [:created_at, :updated_at, :id, :loi_applicant, :loi_organization_name, :loi_email, :loi_phone, :loi_project_title, :program_id, :model_theme_id]
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
  
  def self.included(base)
    base.belongs_to :created_by, :class_name => 'User', :foreign_key => 'created_by_id'
    base.belongs_to :updated_by, :class_name => 'User', :foreign_key => 'updated_by_id'
    base.belongs_to :request
    base.belongs_to :program
    base.belongs_to :user
    base.belongs_to :organization
    base.belongs_to :geo_country
    base.belongs_to :geo_state
    base.has_many :workflow_events, :as => :workflowable

    base.acts_as_audited({:full_model_enabled => false, :except => [:created_by_id, :updated_by_id, :delta, :updated_by, :created_by, :audits]})

    base.insta_search do |insta|
      insta.filter_fields = SEARCH_ATTRIBUTES + [:organization_linked, :applicant_linked, :filter_state]
      insta.derived_filters = {:program_id => (lambda do |search_with_attributes, request_params, name, val|
        prepare_program_ids search_with_attributes, name, val
      end),
      }
    end

    base.insta_realtime do |insta|
      insta.delta_attributes = SEARCH_ATTRIBUTES
      insta.updated_by_field = :updated_by_id
    end
    base.insta_json do |insta|
      insta.add_only 'applicant'
      insta.add_only 'organization_name'
      insta.add_only 'project_title'
      insta.add_only 'email'
      insta.add_only 'phone'
      insta.add_only 'project_summary'
      insta.add_only 'address'
      insta.add_only 'program_id'
      insta.add_only 'amount_requested'
      insta.add_only 'sub_program_id'
      insta.add_only 'duration_in_months'
      insta.add_only 'grant_begins_at'
      insta.add_only 'city'
      insta.add_only 'postal_code'
      insta.add_only 'organization_name_foreign_language'
      
      insta.copy_style :simple, :detailed
    end
    
    base.insta_multi
    base.insta_export do |insta|
      insta.filename = 'loi'
      insta.headers = ['Applicant', 'Organization Name', 'Project Title', ['Date Created', :date], ['Date Updated', :date],
        'Foreign Organization Name',
         'Address', "Address 2", 'City', 'State', 'Country',
         'Postal Code',
         'Email', 'Phone', 
         'Project Summary',
         'Program Name', 'Amount Requested', 'Duration in Months', 
         'Grant Begins At', 'Connected to Request'

      ]
      insta.spreadsheet_cells = [:applicant, :organization_name, :project_title, :created_at, :updated_at,
                :organization_name_foreign_language,
                :address, :street_address2, :city, [:geo_states, :name], [:geo_countries, :name],
                :postal_code,
                :email, :phone,
                :project_summary, [:program, :name], :amount_requested, :duration_in_months, :grant_begins_at, [:request, :grant_or_request_id]]
      insta.sql_query = "lois.applicant, lois.organization_name, lois.project_title, lois.created_at, lois.updated_at,
          lois.organization_name_foreign_language,
          lois.address, lois.street_address2, lois.city, geo_states.name state_name, geo_countries.name country_name, 
          lois.postal_code,
          lois.email, lois.phone, 
          lois.project_summary,
          (select name from programs where programs.id = lois.program_id) program_name,
          lois.amount_requested, lois.duration_in_months,
          lois.grant_begins_at,
          (select base_request_id from requests where requests.id = lois.request_id) base_request_id
          
        from lois
        left outer join geo_states on geo_states.id = lois.geo_state_id
        left outer join geo_countries on geo_countries.id = lois.geo_country_id
        where lois.id IN (?)"
    end
    base.insta_lock

    base.insta_template do |insta|
      insta.entity_name = 'loi'
      insta.add_methods []
      insta.remove_methods [:id]
    end

    base.insta_formbuilder
    base.insta_workflow do |insta|
      insta.add_state_to_english :new, 'Pending Approval', 'new'
      insta.add_state_to_english :approved, 'Approved', 'approved'
      insta.add_event_to_english :approve, 'Approve'
      insta.add_state_to_english :rejected, 'Rejected', 'rejected'
      insta.add_event_to_english :reject, 'Rejected'

      insta.on_enter_state_category('become_request') do |loi|
        loi.promote_to_request
      end

      insta.validate_before_enter_state_category('become_request') do |loi|
        loi.errors[:connect_user] = "You must connect a user before promoting to a request" unless loi.user_id || loi.errors[:connect_user].count > 0
        loi.errors[:connect_organization] = "You must connect an organization before promoting to a request" unless loi.organization_id || loi.errors[:connect_organization].count > 0
      end

    end

    base.insta_favorite
    base.insta_utc do |insta|
      insta.time_attributes = [] 
    end
    base.insta_utc do |insta|
      insta.time_attributes = [:grant_begins_at]
    end
    
    base.insta_filter_amount do |insta|
      insta.amount_attributes = [:amount_requested]
    end
    


    base.extend(ModelClassMethods)
    base.class_eval do
      include ModelInstanceMethods
    end
    
   base.send :include, AASM
   base.add_aasm
    base.add_sphinx if base.respond_to?(:sphinx_indexes) && !(base.connection.adapter_name =~ /SQLite/i)
  end
  

  module ModelClassMethods
    # ESH: hack to rename Loi to LOI
    def model_name
      u = ActiveModel::Name.new Loi
      u.instance_variable_set '@human', 'LOI'
      u
    end
    def add_aasm
      aasm_column :state
      aasm_initial_state :new
      aasm_state :new
    end

    def add_sphinx
      # Allow the overriding of the state name and rewriting of the rejected clause
      state_name = if self.respond_to? :sphinx_state_name
        self.sphinx_state_name
      else
        'state'
      end
      
      include_model_theme_id = self.column_names.include?('model_theme_id')
      
      define_index :loi_first do
        # fields
        indexes "lower(lois.applicant)", :as => :applicant, :sortable => true
        indexes "lower(lois.organization_name)", :as => :organization_name, :sortable => true
        indexes "lower(lois.project_title)", :as => :project_title, :sortable => true
        indexes "lower(lois.email)", :as => :email, :sortable => true

        # attributes
        has created_at, updated_at, deleted_at, program_id
        has "lois.#{state_name}", :type => :string, :crc => true, :as => :filter_state
        has organization_name, :as => :loi_organization_name, :crc => true 
        has "ROUND(lois.amount_requested)", :as => :amount_requested, :type => :integer
        has applicant, :as => :loi_applicant, :crc => true 
        has email, :as => :loi_email, :crc => true 
        has phone, :as => :loi_phone, :crc => true 
        has project_title, :as => :loi_project_title, :crc => true 

        has favorites.user(:id), :as => :favorite_user_ids

        set_property :delta => :delayed
        has "IF(lois.organization_id is not null, 1, 0)", :as => :organization_linked, :type => :boolean
        has "IF(lois.user_id is not null, 1, 0)", :as => :applicant_linked, :type => :boolean
        
        has model_theme_id if include_model_theme_id
      end
    end
  end

  module ModelInstanceMethods
    def first_name
      applicant.gsub(/\s+/, ' ').split(' ').first if applicant
    end

    def last_name
      applicant.gsub(/\s+/, ' ').split(' ').last if applicant
    end

    def user_matches params = {}
      first = params && params[:first_name] ? params[:first_name] : first_name
      last = params && params[:last_name] ? params[:last_name] : last_name
      User.find(:all, :conditions => ["(first_name like ? and last_name like ?) and deleted_at is null", "%#{first}%", "%#{last}%"], :order => "first_name, last_name asc", :limit => 20)
    end

    def organization_matches params = {}
      org = params && params[:organization_name] ? params[:organization_name] : organization_name
      Organization.find(:all, :conditions => ["(name like ?) and deleted_at is null", "%#{org}%"], :order => "name asc", :limit => 20)
    end

    def link_user user
      if user.id
        update_attribute("user_id", user.id)
        if !user.user_profile
          user.update_attribute "user_profile_id", UserProfile.where(:name => 'Grantee').first.id
          user.save
        end
        # Only add the grantee roles if the user's profile is Grantee
        if user.user_profile.name == "Grantee"
          Program.where(:retired => 0).each do |program|
            user.has_role! "Grantee", program
          end
        end
        set_loi_user_primary_org
        #todo email login information
      end
    end

    def link_organization org
      update_attribute("organization_id", org.id)
      set_loi_user_primary_org
    end

    def set_loi_user_primary_org
      if user && organization && !user.primary_organization
        user_org = UserOrganization.where(:user_id => user.id, :organization_id => organization.id).first
        unless user_org
          user_org = UserOrganization.new({:user_id => user.id, :organization_id => organization.id})
          user_org.save
        end
        user.update_attribute "primary_user_organization_id", user_org.id
      end
    end

    def loi_applicant
      applicant
    end
    
    def loi_organization_name
      organization_name
    end   
    
    def loi_email
      email
    end
    
    def loi_phone
      phone
    end
    
    def loi_project_title
      project_title
    end

    def promote_to_request
      unless request_id
        to_theme_id = request_theme_id
        unless to_theme_id
          first_request_theme = ModelTheme.where(:model_type => "Request", :deleted_at => nil).first
          to_theme_id = first_request_theme.id if first_request_theme
        end
        if to_theme_id
          attributes = { :program_organization_id => organization_id, :program_id => program_id, :amount_requested => amount_requested, :model_theme_id => to_theme_id,
           :duration_in_months => duration_in_months,:grant_begins_at => grant_begins_at, :project_summary => project_summary, :grantee_org_owner_id => user_id }
          if request_attributes
            workflow_attributes = request_attributes.de_json
            attributes.merge!(workflow_attributes["grant_request"]) if workflow_attributes.is_a?(Hash) && workflow_attributes["grant_request"]
          end
          request = GrantRequest.new(attributes)

          draft_state = Request.all_states_with_category("draft").first
          request.state = draft_state if draft_state

          if request.save(:validate => false)
            if request_note
              note = Note.new(:notable_id => request.id, :notable_type => request.class.name, :note => request_note)
              note.save
            end

            request_attributes = request.all_dynamic_attributes
            all_dynamic_attributes.each do |k,v|
              request.send("#{k}=", self.send(k)) if request_attributes[k]
            end
            request.project_title = project_title if self.respond_to? :project_title
            request.save(:validate => false)
            self.update_attribute :request_id, request.id
            #expire workflow cache for request
            MachineWorkflow.expire_model_cache request
          end
          request
        end
      end
    end
  end
end