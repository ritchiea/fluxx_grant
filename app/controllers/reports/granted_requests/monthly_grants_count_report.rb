class MonthlyGrantsCountReport < ActionController::ReportBase
  include MonthlyGrantsBaseReport
  insta_report(:plot) do |insta|
    insta.report_label = lambda{|report, config| "Monthly Grants By #{I18n.t(:program_name)}"}
  end
  
  def compute_plot_data controller, index_object, params, report_vars, models
    hash = by_month_report models.map(&:id), params, :count
    hash[:title] = report_label
    hash.to_json
  end
end
