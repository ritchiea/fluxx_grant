module ApplicationGrantHelper
  def render_grant_id request
    return '' unless request
    if request.is_grant?
      request.grant_id
    end
  end

  def render_request_id request
    return '' unless request
    request.request_id
  end

  def render_grant_or_request_id request
    return '' unless request
    render_grant_id(request) || render_request_id(request)
  end

  def render_text_program_name request, include_fiscal=true
    return '' unless request
    if request.is_a? FipRequest
      request.fip_title
    else
      org_name = if request.program_organization
        request.program_organization.display_name
      end
      fiscal_org_name = if include_fiscal && request.fiscal_organization && request.program_organization != request.fiscal_organization
        "a project of #{request.fiscal_organization.display_name}"
      end
      [org_name, fiscal_org_name].compact.join ', '
    end
  end

  def render_program_name request, include_fiscal=true
    return '' unless request
    if request.is_a? FipRequest
     raw "<span class=\"minimize-detail-pull\">#{request.fip_title}</span> <br />"
    else
      org_name = if request.program_organization
        request.program_organization.display_name
      end || ''
      fiscal_org_name = if include_fiscal && request.fiscal_organization
        ", a project of #{request.fiscal_organization.display_name}"
      end || ''
      raw "<span class=\"minimize-detail-pull\">#{org_name + fiscal_org_name}</span> <br />"
    end
  end

  def render_grant_amount request, grant_text='Granted'
    return '' unless request
    if request.is_grant?
      "#{as_currency(request.amount_recommended)} #{grant_text}"
    end
  end

  def render_request_amount request, request_text
    return '' unless request
    if request.display_amount
      "#{request_text} <span class='minimize-detail-pull'>#{as_currency(request.display_amount)}</span> <br />"
    end
  end

  def render_request_or_grant_amount request, grant_text='Granted', request_text='Request for'
    raw render_grant_amount(request, grant_text) || render_request_amount(request, request_text)
  end

  def build_add_card_links
    links = []
    grant_fip_name = if Fluxx.config(:hide_fips) == "1"
      "Grants"
    else
      "Grants / #{I18n.t(:fip_name).pluralize}"
    end
    links << "  '<h3>Grants Management</h3>'";
    links << "  '#{link_to 'LOIs', lois_path(:filter_state => 'new'), :class => 'new-listing indent'}'" unless Fluxx.config(:hide_lois) == "1" || !current_user.has_listview_for_model?(Loi)
    links << "  '#{link_to 'Requests', grant_requests_path, :class => 'new-listing indent'}'" unless Fluxx.config(:hide_requests) == "1" || !current_user.has_listview_for_model?(Request) || current_user.is_board_member?
    links << "  '#{link_to grant_fip_name, granted_requests_path, :class => 'new-listing indent'}'" unless Fluxx.config(:hide_grants) == "1" || !current_user.has_listview_for_model?(Request)
    links << "  '#{link_to 'Grantee Reports', request_reports_path, :class => 'new-listing indent'}'" unless Fluxx.config(:hide_grantee_reports) == "1" || !current_user.has_listview_for_model?(RequestReport)
    links << "  '#{link_to 'Transactions', request_transactions_path, :class => 'new-listing indent'}'" unless Fluxx.config(:hide_transactions) == "1" || !current_user.has_listview_for_model?(RequestTransaction)
    links << "  '#{link_to 'Amendments', request_amendments_path, :class => 'new-listing indent'}'" if Fluxx.config(:show_request_amendments_card) == "1" && current_user.has_listview_for_model?(RequestAmendment)
    #links << "  '#{link_to 'Budgeting', admin_card_path(:id => 1), :class => 'new-detail indent'}'" unless Fluxx.config(:hide_admin_cards) == "1" || !current_user.has_listview_for_model?(Program)

    links << "  '<h3>Budgeting</h3>'"
    links << "  '#{link_to 'Funding Sources',funding_sources_path, :class => 'new-listing indent'}'" unless Fluxx.config(:hide_funding_sources) == "1" || !current_user.has_listview_for_model?(FundingSource)
    links << "  '#{link_to I18n.t(:program_name).pluralize, programs_path, :class => 'new-listing indent'}'" unless Program.is_hidden? || !current_user.has_listview_for_model?(Program)
    links << "  '#{link_to I18n.t(:sub_program_name).pluralize, sub_programs_path, :class => 'new-listing indent'}'" unless SubProgram.is_hidden? || !current_user.has_listview_for_model?(SubProgram)
    links << "  '#{link_to I18n.t(:initiative_name).pluralize, initiatives_path, :class => 'new-listing indent'}'" unless Initiative.is_hidden? || !current_user.has_listview_for_model?(Initiative)
    links << "  '#{link_to I18n.t(:sub_initiative_name).pluralize, sub_initiatives_path, :class => 'new-listing indent'}'" unless SubInitiative.is_hidden? || !current_user.has_listview_for_model?(SubInitiative)

    links << "  '<h3>Contact Management</h3>'";
    links << "  '#{link_to 'People', users_path, :class => 'new-listing indent'}'" unless Fluxx.config(:hide_people) == "1" || !current_user.has_listview_for_model?(User)
    links << "  '#{link_to I18n.t(:Organization).pluralize, organizations_path, :class => 'new-listing indent'}'" unless Fluxx.config(:hide_organizations) == "1" || !current_user.has_listview_for_model?(Organization)

    links << "  '<h3>Project Management</h3>'" unless (Fluxx.config(:hide_projects) == "1" || !current_user.has_listview_for_model?(Project)) && (Fluxx.config(:hide_tasks) == "1" || !current_user.has_listview_for_model?(WorkTask))
    links << "  '#{link_to 'Projects', projects_path, :class => 'new-listing indent'}'" unless Fluxx.config(:hide_projects) == "1" || !current_user.has_listview_for_model?(Project)
    links << "  '#{link_to 'Tasks', work_tasks_path, :class => 'new-listing indent'}'" unless Fluxx.config(:hide_tasks) == "1" || !current_user.has_listview_for_model?(WorkTask)

    links.join ",\n"
  end

  def build_adminlink
    if current_user.is_admin?
      if Fluxx.config :legacy_admin
        "'#{link_to 'Admin', admin_card_path(:id => 1), :class => 'new-detail'}',"
      else
       "'#{link_to 'Admin', admin_items_path(:id => 'workflows'), :class => 'to-fullscreen-modal', "data-container-id" => "fluxx-admin"}',"
      end
    else
      ""
    end
  end

  def build_reportlink
    if current_user.has_view_for_model? RequestReport
      "'#{link_to 'Live Reports', modal_reports_path, :class => 'report-modal'}',"
    else
      ""
    end
  end
  
  def build_request_quicklinks
    #p "ESH: in build_request_quicklinks of application grant helper"
    request_links = []
    request_links << "  '#{link_to 'New Grant Request', new_grant_request_path, :class => 'new-detail'}'\n" unless Fluxx.config(:hide_requests) == "1"
    request_links << "  '#{link_to 'New ' + I18n.t(:fip_name) + ' Request', new_fip_request_path, :class => 'new-detail'}'\n" unless Fluxx.config(:hide_requests) == "1" || Fluxx.config(:hide_fips) == "1"
    request_links
  end

  def build_quicklinks
    links = []
    links << "{
      label: 'New Request',
      url: '#',
      className: 'noop',
      type: 'style-ql-documents small',
      popup: [#{build_request_quicklinks.join ",\n"}
      ]
    }" unless Fluxx.config(:hide_requests) == "1" && Fluxx.config(:hide_grants) == "1" || !current_user.has_create_for_model?(Request)
    links << "{
      label: 'New Org',
      url: '#{new_organization_path}',
      className: 'new-detail',
      type: 'style-ql-library small'
    }" unless Fluxx.config(:hide_organizations) == "1" || !current_user.has_create_for_model?(Organization)
    links << "{
      label: 'New Person',
      url: '#{new_user_path}',
      className: 'new-detail',
      type: 'style-ql-user small'
    }" unless Fluxx.config(:hide_people) == "1" || !current_user.has_create_for_model?(User)
    links << "{
      label: 'New Project',
      url: '#{new_project_path}',
      className: 'new-detail',
      type: 'style-ql-project small'
    }" unless Fluxx.config(:hide_projects) == "1" || !current_user.has_create_for_model?(Project)
    links.join ",\n"
  end
  
  EVAL_RATING_MAP = {1 => "1: grant failed", 2 => "2: performed below expectations", 3 => "3: met expectations", 4 => "4: exceeded expectations", 5 => "5: far exceeded expectations"}
  
  def eval_ratings_for_input
    EVAL_RATING_MAP.keys.sort.map do |key|
      [EVAL_RATING_MAP[key], key]
    end
  end
  
  def eval_rating_to_text rating
    EVAL_RATING_MAP[rating]
  end
  
  # Derive an english word for the state that is appropriate for the grantee and reviewer portal
  def portal_user_state_for_request model, alternate_view_names={}
    if model.is_grant?
      if model.in_state_with_category?("grant_closed")
        alternate_view_names[:closed] || "Closed" 
      else
        alternate_view_names[:active] || "Active"
      end
    else
      actions_available = model.actions(current_user)
      if !actions_available.empty?
        if model.in_sentback_state? 
          alternate_view_names[:more_info_requested] || "More info Requested" 
        else
          alternate_view_names[:draft] || "Draft" 
        end
      else
        if model.in_reject_state?
          alternate_view_names[:declined] || "Declined" 
        elsif model.is_marked_complete?
          alternate_view_names[:decision_pending] || "Decision Pending" 
        else
          alternate_view_names[:submitted] || "Submitted" 
        end
      end
    end
  end
end