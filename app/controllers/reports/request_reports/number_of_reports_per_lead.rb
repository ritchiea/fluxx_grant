class NumberOfReportsPerLead < ActionController::ReportBase
  insta_report(:plot) do |insta|
    insta.report_label = 'Reports Pending Lead Approval'
  end

  def compute_plot_data controller, index_object, params, report_vars, models
    hash = {:library => "jqplot"}
    hash[:title] = report_label
    hash[:data] = []
    query = "select count(rr.id) as count, u.first_name, u.last_name, rr.report_type as report_type, u.id as user_id from request_reports rr
      left join requests r on r.id = rr.request_id
      right join users u on u.id = r.program_lead_id
      where report_type != '' and rr.state != 'approved' AND rr.id in (?)
      group by u.id, rr.report_type
      order by rr.report_type,  u.last_name"
    data = RequestReport.connection.execute(RequestReport.send(:sanitize_sql, [query, models.map(&:id)]))
    xaxis = []
    user_ids = []
    report_types = []
    report_count = {}
    max = 0
    data.each(:cache_rows => false, :symbolize_keys => true, :as => :hash) do |row|
      if !user_ids.include?(row[:user_id])
        user_ids << row[:user_id]
        xaxis << "#{row[:first_name]} #{row[:last_name]}"
      end
      report_types << row[:report_type] unless report_types.include?(row[:report_type])
      report_count[row[:report_type]] = {} unless report_count[row[:report_type]]
      report_count[row[:report_type]][row[:user_id]] = row[:count]
      max = row[:count] if max < row[:count]
    end

    report_count.sort.each do |report_type, counts_by_user|
      hash[:data] << []
      user_ids.each do |user_id|
        hash[:data].last << (counts_by_user[user_id].nil? ? 0 : counts_by_user[user_id])
      end
    end

    hash[:data] = ReportUtility.convert_bigdecimal_to_f_in_array hash[:data]
    hash[:axes] = { :xaxis => {:ticks => xaxis, :tickOptions => { :angle => -30 }}, :yaxis => { :min => 0, :max => max + 10, :tickOptions => { :formatString => "%.0f" } }}
    hash[:series] = report_types.map{|report_type| {:label => report_type}}
    hash[:stackSeries] = false;
    hash[:type] = "bar"

    hash.to_json
  end

  def report_filter_text controller, index_object, params, report_vars, models
  end

  def report_summary controller, index_object, params, report_vars, models
  end

  def report_legend controller, index_object, params, report_vars, models
    legend = [{:table => ['Report Type', 'Number of Reports Due']}]
    query = "select count(rr.id) as count, report_type from request_reports rr where report_type != '' and rr.state != 'approved' and id in (?) group by report_type order by report_type"
    filter = []
    params["request_report"].each do |key, value|
      next if key == "report_type"
      if value.is_a? Array
        value.each {|val| filter << "request_report[#{key}][]=#{val}"}
      else
        filter << "request_report[#{key}]=#{value}"
      end
    end if params["request_report"]
    RequestReport.connection.execute(Request.send(:sanitize_sql, [query, models.map(&:id)])).each(:cache_rows => false, :symbolize_keys => true, :as => :hash) do |result|
      legend << { :table => [result[:report_type], result[:count]],
                  :filter =>  filter.join("&") + "&request_report[report_type][]=#{result[:report_type]}",
        :listing_url => controller.request_reports_path, :card_title => "#{result[:report_type]} Reports"}
    end
    legend
  end
end