class ReviewerFeedbackReport < ActionController::ReportBase
  include ReviewerBaseReport
  insta_report(:download) do |insta|
    insta.filter_template = 'modal_reports/reviewer_feedback_filter'
    insta.report_label = 'Reviewer Feedback Report'
    insta.report_description = 'External Reviewer Feedback By Grant Report (Excel Table)'
  end

  def compute_document_headers controller, show_object, params, report_vars, models
    ['fluxx_' + 'reviewer_feedback' + '_' + Time.now.strftime("%m%d%y") + ".xls", 'application/vnd.ms-excel']
  end

  def compute_document_data controller, show_object, params, report_vars, models
    base_compute_show_document_data controller, show_object, params, report_vars, :feedback
  end
end