class BudgetOverviewByYear < ActionController::ReportBase
  include BudgetOverviewBaseReport

  insta_report(:plot) do |insta|
    insta.filter_template = 'modal_reports/funding_year_and_program_filter'
    insta.report_order = -10
    insta.report_label = 'Budget Overview Chart (by Program)'
    insta.report_description = "View current status of each allocation: amount spent, amount in the pipeline and amount allocated (Bar Chart)"
  end
end