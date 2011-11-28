class SimpleDocketReport < ActionController::ReportBase
  insta_report(:show) do |insta|
    insta.filter_template = 'modal_reports/simple_docket_filter'
    insta.report_order = 2
    insta.report_label = 'Content Generator'
    insta.report_description = 'Used to collate content documents across a range of requests (HTML/PDF)'
    insta.report_visible_block = lambda{|report, config| Fluxx.config(:show_simple_docket_report) == '1'}
  end

  include BaseSimpleDocketReport
end