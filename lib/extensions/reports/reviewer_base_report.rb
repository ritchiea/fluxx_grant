module ReviewerBaseReport
  def base_compute_show_document_data controller, show_object, params, report_vars, extra_conditions=nil
    active_record_params = params[:active_record_base] || {}

    start_date = if active_record_params[:start_date].blank?
      nil
    else
      Time.parse_localized(active_record_params[:start_date]) rescue nil
    end || Time.now.beginning_of_year
    end_date = if active_record_params[:end_date].blank?
      nil
    else
      Time.parse_localized(active_record_params[:end_date]) rescue nil
    end || Time.now.end_of_year

    programs = active_record_params[:program_id]
    programs = if active_record_params[:program_id]
      Program.where(:id => active_record_params[:program_id]).all rescue nil
    end || []
    programs = programs.compact

    lead_users = active_record_params[:lead_user_ids]
    lead_users = if active_record_params[:lead_user_ids]
      User.where(:id => active_record_params[:lead_user_ids]).all rescue nil
    end || []
    lead_users = lead_users.compact
    
    assignments = RequestReviewerAssignment.joins(:request).where([%{
      #{start_date ? " request_received_at >= '#{start_date.sql}' AND " : ''} 
      #{end_date ? " request_received_at <= '#{end_date.sql}' AND " : ''}
      requests.deleted_at IS NULL AND 
      granted = 0 AND
      requests.state not in (?) AND
      (1=? or requests.program_id in (?)) AND
      (1=? or requests.program_lead_id in (?))}, 
      Request.all_rejected_states,
      programs.empty?, programs,
      lead_users.empty?, lead_users
      ]).all
      
    assigned_users = User.where(:id => assignments.map(&:user_id)).all

    reviews = 
      RequestReview.joins(:request).where([%{
        #{start_date ? " request_received_at >= '#{start_date.sql}' AND " : ''} 
        #{end_date ? " request_received_at <= '#{end_date.sql}' AND " : ''}
        requests.deleted_at IS NULL AND 
        granted = 0 AND
        requests.state not in (?) AND
        (1=? or requests.program_id in (?)) AND
        (1=? or requests.program_lead_id in (?))}, 
        Request.all_rejected_states,
        programs.empty?, programs,
        lead_users.empty?, lead_users
        ])
    reviews = reviews.where(extra_conditions) if extra_conditions
    user_ids = reviews.map(&:created_by_id).uniq
    request_ids = reviews.map(&:request_id).uniq
    users = User.where(:id => user_ids).order('last_name, first_name').all
    users_by_userid = users.inject({}) {|acc, user| acc[user.id] = user; acc}
    requests = Request.find_by_sql ["
      select requests.*, if(type = 'GrantRequest', (select name from organizations where id = program_organization_id), fip_title) report_grant_name,
      grant_begins_at report_begin_date,
      if(grant_begins_at is not null and duration_in_months is not null, date_add(date_add(grant_begins_at, INTERVAL duration_in_months month), interval -1 DAY), grant_begins_at) report_end_date
      from requests 
      where id in (?)", request_ids]
    requests_by_requestid = requests.inject({}) {|acc, request| acc[request.id] = request; acc}

    reviews_by_request_id = {}
    reviews_by_request_id = reviews.inject({}) do |acc, review|
      review_hash = acc[review.request_id] || {}
      acc[review.request_id] = review_hash
      review_hash[review.created_by_id] = review
      acc
    end

    [start_date, end_date, reviews_by_request_id, requests_by_requestid, assigned_users, assignments, reviews, user_ids, request_ids, users, users_by_userid, requests]

  end
end