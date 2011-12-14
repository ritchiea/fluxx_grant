class GrantsByFundingSourceReport < ActionController::ReportBase
  insta_report(:download) do |insta|
    insta.filter_template = 'modal_reports/grants_by_funding_source_filter'
    insta.report_label = 'Funder Detail Report'
    insta.report_description = 'Grant listing of funds committed, by Funder (Excel Table)'
  end

  def compute_document_headers controller, show_object, params, report_vars, models
    ['fluxx_' + 'grants_by_funding_source' + '_' + Time.now.strftime("%m%d%y") + ".xls", 'application/vnd.ms-excel']
  end

  def compute_document_data controller, show_object, params, report_vars, models
    active_record_params = params[:active_record_base] || {}
    
    case active_record_params[:date_range_type]
    when 'this_week'
      start_date = Time.now.ago(7.days)
      end_date = Time.now
    when 'last_week'
      start_date = Time.now.ago(14.days)
      end_date = Time.now.ago(7.days)
    else
      start_date = if active_record_params[:start_date].blank?
        nil
      else
        Time.parse_localized(active_record_params[:start_date]) rescue nil
      end || Time.now
      end_date = if active_record_params[:end_date].blank?
        nil
      else
        Time.parse_localized(active_record_params[:end_date]) rescue nil
      end || Time.now
    end

    programs = active_record_params[:program_id]
    programs = if active_record_params[:program_id]
      Program.where(:id => active_record_params[:program_id]).all rescue nil
    end || []
    programs = programs.compact

    sub_programs = active_record_params[:sub_program_id]
    sub_programs = if active_record_params[:sub_program_id]
      SubProgram.where(:id => active_record_params[:sub_program_id]).all rescue nil
    end || []
    sub_programs = sub_programs.compact

    funding_sources = active_record_params[:funding_source_ids]
    funding_sources = if active_record_params[:funding_source_ids]
      FundingSource.where(:id => active_record_params[:funding_source_ids]).all rescue nil
    end || []
    funding_sources = funding_sources.compact
    
    lead_users = active_record_params[:lead_user_ids]
    lead_users = if active_record_params[:lead_user_ids]
      User.where(:id => active_record_params[:lead_user_ids]).all rescue nil
    end || []
    lead_users = lead_users.compact
    
    
    requests = FundingSourceAllocation.build_temp_table do |temp_table_name|
      Request.find_by_sql [%{select (select name from programs where id = temp_table.program_id) report_program_name, 
                  (select name from sub_programs where id = temp_table.sub_program_id) report_sub_program_name,
                  (select name from initiatives where id = temp_table.initiative_id) report_initiative_name,
                  (select name from sub_initiatives where id = temp_table.sub_initiative_id) report_sub_initiative_name,
                  temp_table.report_spending_year,
                  if(type = 'GrantRequest', (select name from organizations where id = program_organization_id), fip_title) report_grant_name,
                  base_request_id,
                  amount_recommended,
                  grant_begins_at report_begin_date,
                  if(grant_begins_at is not null and duration_in_months is not null, date_add(date_add(req.grant_begins_at, INTERVAL duration_in_months month), interval -1 DAY), grant_begins_at) report_end_date,
                  (select name from funding_sources where funding_sources.id = temp_table.funding_source_id) report_funder_name,
                  rfs.funding_amount report_funding_amount
                  from #{temp_table_name} temp_table, request_funding_sources rfs, requests req
                  where temp_table.id = rfs.funding_source_allocation_id and rfs.funding_source_allocation_id is not null and
                  rfs.request_id = req.id and
                  #{start_date ? " grant_agreement_at >= '#{start_date.sql}' AND " : ''} 
                  #{end_date ? " grant_agreement_at <= '#{end_date.sql}' AND " : ''}
                  req.deleted_at IS NULL AND 
                  req.state not in (?) AND
                  (1=? or req.program_id in (?)) AND
                  (1=? or req.sub_program_id in (?)) AND
                  (1=? or temp_table.funding_source_id in (?)) AND
                  (1=? or req.program_lead_id in (?))
                  }, 
                  Request.all_rejected_states,
                  programs.empty?, programs,
                  sub_programs.empty?, sub_programs,
                  funding_sources.empty?, funding_sources,
                  lead_users.empty?, lead_users
      ]
    end
    

    
     output = StringIO.new

     workbook = WriteExcel.new(output)
     worksheet = workbook.add_worksheet

     non_wrap_bold_format, bold_format, header_format, solid_black_format, amount_format, number_format, date_format, text_format, header_format, 
         sub_total_format, sub_total_border_format, total_format, total_border_format, final_total_format, final_total_border_format, 
         bold_total_format, double_total_format = build_formats(workbook)

     # Add page summary
     # worksheet.write(0, 0, 'The Energy Foundation', non_wrap_bold_format)
     worksheet.write(1, 0, 'Grants by Funding Source', non_wrap_bold_format)
     worksheet.write(2, 0, 'Start Date: ' + start_date.mdy) if start_date
     worksheet.write(3, 0, 'End Date: ' + end_date.mdy) if end_date
     worksheet.write(4, 0, "Report Date: " + Time.now.mdy)

     # Adjust column widths
     worksheet.set_column(0, 9, 10)
     worksheet.set_column(1, 1, 15)
     worksheet.set_column(7, 7, 20)
     worksheet.set_column(9, 9, 15)

     [I18n.t(:program_name), I18n.t(:sub_program_name), I18n.t(:initiative_name), I18n.t(:sub_initiative_name), "Spending Year", "Grant Name", "Grant ID", "Amount Funded (total grant)", "Start Date", "End Date", "Funder Name", "Funded Amounts"].
       each_with_index{|label, index| worksheet.write(6, index, label, header_format)}

     row_start = 6
     total_column_name = "J"
     row = row_start
     
     requests.each do |request|
      worksheet.write(row += 1, 0, request.report_program_name)
      worksheet.write(row, 1, request.report_sub_program_name)
      worksheet.write(row, 2, request.report_initiative_name)
      worksheet.write(row, 3, request.report_sub_initiative_name)
      worksheet.write(row, 4, request.report_spending_year)
      worksheet.write(row, 5, request.report_grant_name)
      worksheet.write(row, 6, request.base_request_id)
      worksheet.write(row, 7, (request.amount_recommended), amount_format)
      worksheet.write(row, 8, (request.report_begin_date ? request.report_begin_date.mdy : nil), date_format)
      worksheet.write(row, 9, (request.report_end_date ? request.report_end_date.mdy : nil), date_format)
      worksheet.write(row, 10, request.report_funder_name)
      worksheet.write(row, 11, (request.report_funding_amount), amount_format)
    end

    workbook.close
    output.string
  end
end