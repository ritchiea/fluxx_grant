class MonthlyGrantsCountReport < ActionController::ReportBase
  include MonthlyGrantsBaseReport
  set_type_as_index
  def report_label
    "Monthly Grants By #{I18n.t(:program_name)}"
  end
  
  def pre_compute controller, index_object, params, models
  end
  
  def compute_index_plot_data controller, index_object, params, models, report_vars
    hash = by_month_report models.map(&:id), params, :count
    hash[:title] = report_label
    hash.to_json
  end
end
