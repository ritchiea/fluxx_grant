class ReviewerExportReport < ActionController::ReportBase
  include ReviewerBaseReport
  insta_report(:download) do |insta|
    insta.filter_template = 'modal_reports/reviewer_export_filter'
    insta.report_label = 'Reviewer Export Report'
    insta.report_description = 'External Reviewer Export (Excel Table)'
  end

  def compute_document_headers controller, show_object, params, report_vars, models
    ['fluxx_' + 'reviewer_export' + '_' + Time.now.strftime("%m%d%y") + ".xls", 'application/vnd.ms-excel']
  end

  def compute_document_data controller, show_object, params, report_vars, models
      start_date, end_date, reviews_by_request_id, requests_by_requestid, assigned_users, assignments, reviews, user_ids, request_ids, users, users_by_userid, requests = base_compute_show_document_data(controller, show_object, params, report_vars)
      output = StringIO.new

      workbook = WriteExcel.new(output)
      worksheet = workbook.add_worksheet

      non_wrap_bold_format, bold_format, header_format, solid_black_format, amount_format, number_format, date_format, text_format, header_format, 
          sub_total_format, sub_total_border_format, total_format, total_border_format, final_total_format, final_total_border_format, 
          bold_total_format, double_total_format = build_formats(workbook)
      # Add page summary
      # worksheet.write(0, 0, 'The Energy Foundation', non_wrap_bold_format)
      worksheet.write(1, 0, 'Reviewer Feedback', non_wrap_bold_format)
      worksheet.write(2, 0, 'Start Date: ' + start_date.mdy) if start_date
      worksheet.write(3, 0, 'End Date: ' + end_date.mdy) if end_date
      worksheet.write(4, 0, "Report Date: " + Time.now.mdy)

      # Adjust column widths
      worksheet.set_column(0, 9, 10)
      worksheet.set_column(1, 1, 15)
      worksheet.set_column(7, 7, 20)
      worksheet.set_column(9, 9, 15)
      column_letters = calculate_column_letters

      row_start = 6
      row = row_start

      program_hash = Program.all.inject({}) {|acc, program| acc[program.id] = program; acc}
      sub_program_hash = SubProgram.all.inject({}) {|acc, program| acc[program.id] = program; acc}

      column_headers = ["Grant Name", "Grant ID", I18n.t(:program_name), I18n.t(:sub_program_name), "Amount Requested", "Amount Recommended", "Start Date", "End Date", "Duration", "Reviewer Name", "Rating", "Review Type", "Comment", "Benefits", "Outcomes", "Merits", "Recommendation"]
      if Fluxx.config(:dont_use_duration_in_requests) == "1"
        column_headers.delete "Duration"
      end

      column_headers.each_with_index{|label, index| worksheet.write(6, index, label, header_format)}

      reviews.each do |review|
        request_id = review.request_id
        column=0
        request = requests_by_requestid[request_id]

        worksheet.write(row += 1, column, request.report_grant_name)
        worksheet.write(row, column += 1, request.base_request_id)
        program = program_hash[request.program_id]
        worksheet.write(row, column += 1, program ? program.name : nil)
        sub_program = sub_program_hash[request.sub_program_id]
        worksheet.write(row, column += 1, sub_program ? sub_program.name : nil)
        worksheet.write(row, column += 1, (request.amount_requested), amount_format)
        worksheet.write(row, column += 1, (request.amount_recommended), amount_format)
        worksheet.write(row, column += 1, (request.report_begin_date ? request.report_begin_date.mdy : ''), date_format)

        if Fluxx.config(:dont_use_duration_in_requests) == "1"
          if request.is_a?(FipRequest)
            worksheet.write(row, column += 1, (request.fip_projected_end_at ? request.fip_projected_end_at.mdy : ''), date_format)
          else
            worksheet.write(row, column += 1, (request.grant_closed_at ? request.grant_closed_at.mdy : ''), date_format)
          end
        elsif request.is_a?(FipRequest)
          worksheet.write(row, column += 1, (request.fip_projected_end_at ? request.fip_projected_end_at.mdy : ''), date_format)
          column += 1 # Fips still have a duration column
        else
          worksheet.write(row, column += 1, (request.report_end_date ? request.report_end_date.mdy : ''), date_format)
          worksheet.write(row, column += 1, request.duration_in_months, number_format)
        end

        user = users_by_userid[review.created_by_id]
        worksheet.write(row, column += 1, user ? user.full_name : nil)
        worksheet.write(row, column += 1, review.rating, number_format)
        worksheet.write(row, column += 1, review.review_type)
        worksheet.write(row, column += 1, review.comment)
        worksheet.write(row, column += 1, review.benefits)
        worksheet.write(row, column += 1, review.outcomes)
        worksheet.write(row, column += 1, review.merits)
        worksheet.write(row, column += 1, review.recommendation)
      end

      workbook.close
      output.string
  end
end
