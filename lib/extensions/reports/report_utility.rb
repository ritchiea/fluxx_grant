module ReportUtility
# Static function to help with SQL queries

 # TODO AML: Instead of assuming the Request object is available, just use the ActiveRecord class directly
 # TODO AML: Create a better hook for PRE_PIPELINE_STATES
 # TODO AML: Document each helper function
  PRE_PIPELINE_STATES = ['new', 'funding_recommended', 'rejected']

  # General helpers
  def self.pre_pipeline_states
    PRE_PIPELINE_STATES
  end

  def self.get_program_ids program_id_param, return_all_if_nil = true
    if (program_id_param)
      program_id_param.map {|program| program.to_i}
    elsif return_all_if_nil
      query = 'SELECT id FROM programs WHERE retired = 0'
      array_query([query])
    else
      return []
    end
  end

  def self.get_initiative_ids initiative_id_param, return_all_if_nil = true
    if (initiative_id_param)
      initiative_id_param.map {|initiative| initiative.to_i}
    elsif return_all_if_nil
      query = 'SELECT id FROM initiatives WHERE retired = 0'
      array_query([query])
    else
      return []
    end
  end


  # Take an array of IDs and return an array of the same size with the results filled in with the result that matches each array element.
  # For example, if you pass in a list of program_ids = [4, 19, 3, 10]
  # And provide a query that sums up the amount of allocation for each program ID, the result should
  # be an array with [allocation for program 4, allocation for program 19, allocation for program 3, allocation for program 10]
  def self.query_map_to_array(query, array, map_field, result_field)
    req = Request.connection.execute(Request.send(:sanitize_sql, query))
    results = Array.new.fill(0, 0, array.length)
    req.each(:cache_rows => false, :symbolize_keys => true, :as => :hash) do |res|
      i = array.index(res[map_field])
      if i
        results[i] = res[result_field]
      end
    end
    results
  end

  # Grab the ID field from the returned result set
  def self.array_query(query, result_field = :id)
    req = Request.connection.execute(Request.send(:sanitize_sql, query))
    results = []
    req.each(:cache_rows => false, :symbolize_keys => true, :as => :hash){ |res| results << res[result_field] }
    return results
  end

  # Return the last row of the result set of a query.
  # It's expected that the query will return one row, but if it returns more than one, it will just return the last result
  def self.single_value_query(query)
    req = Request.connection.execute(Request.send(:sanitize_sql, query))
    req.each(:cache_rows => false, :symbolize_keys => true, :as => :hash){ |res| return res}
  end

  def self.get_xaxis(start_date, stop_date, category_only = true)
    i = 0
    get_months_and_years(start_date, stop_date).collect{ |date| category_only ? date[0].to_s + "/" + date[1].to_s : [i = i + 1, date[0].to_s + "/" + date[1].to_s] }
  end

  # Return query data with values for all months within a range
  def self.normalize_month_year_query(query, start_date, stop_date, result_field=:amount)
    req = Request.connection.execute(Request.send(:sanitize_sql, query))
    data = get_months_and_years(start_date, stop_date)
    req.each(:cache_rows => false, :symbolize_keys => true, :as => :hash) do |row|
      i = data.index([row[:month], row[:year]])
      data[i] << row[result_field]
    end
    data.collect { |point| point[2] }
  end

  def self.get_months_and_years(start_date, stop_date)
    m1 = Month.new start_date.year, start_date.month
    m2 = Month.new stop_date.year, stop_date.month
   (m1..m2).collect { |date| [date.month, date.year] }.uniq
  end

  def self.get_years(start_date, stop_date)
    y1 = Year.new start_date.year
    y2 = Year.new stop_date.year
   (y1..y2).collect { |date| date.year }.uniq
  end

  # Helpers specific to visualizations

  def self.get_report_totals request_ids
    hash = {}
    query = "select count(id) as num, sum(amount_recommended) as amount from requests r where id in (?) and type = (?)"
    res = ReportUtility.single_value_query([query, request_ids, "GrantRequest"])
    hash[:grants] = res[:num]
    hash[:grants_total] = res[:amount]
    res = ReportUtility.single_value_query([query, request_ids, "FipRequest"])
    hash[:fips] = res[:num]
    hash[:fips_total] = res[:amount]
    hash
  end
  
  def self.convert_bigdecimal_to_f_in_array my_array
    my_array.map do |element|
      if element.is_a?(BigDecimal)
        element.to_f 
      elsif element.is_a?(Array)
        convert_bigdecimal_to_f_in_array(element)
      else
        element
      end
    end
  end
end