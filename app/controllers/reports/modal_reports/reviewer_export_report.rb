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
    base_compute_show_document_data controller, show_object, params, report_vars, :export
  end
end