class MonthlyGrantsMoneyReport < ActionController::ReportBase
  include MonthlyGrantsBaseReport
  insta_report(:plot) do |insta|
    insta.report_label = lambda{|report, config| "Grant #{CurrencyHelper.current_long_name.pluralize} By Month"}
  end

  def compute_plot_data controller, index_object, params, report_vars, models
    hash = by_month_report models.map(&:id), params, :sum_amount
    hash[:title] = report_label
    hash.to_json
  end
end
