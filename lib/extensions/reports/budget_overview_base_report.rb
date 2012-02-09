module BudgetOverviewBaseReport
  def compute_plot_data controller, index_object, params, report_vars, models
    filter = params["active_record_base"]
    hash = {}
    hash[:title] = index_object.report_label
    FundingSourceAllocation.build_temp_table do |temp_table_name|

      ids, grouping_table, grouping_col = get_grouping_parameters params
      start_date, stop_date = get_date_range filter
      years = ReportUtility.get_years start_date, stop_date

      # Never include these requests
      rejected_states = Request.send(:sanitize_sql, ['(?)', Request.all_rejected_states])
      paid_states = Request.send(:sanitize_sql, ['(?)', RequestTransaction.all_states_with_category('paid').map{|state| state.to_s}])

      always_exclude = "r.deleted_at IS NULL AND r.state not in #{rejected_states}"

      # Selected Programs or Initiatives

      query = "SELECT name, id FROM #{grouping_table} WHERE id IN (?)"
      groups = ReportUtility.query_map_to_array([query, ids], ids, :id, :name)

      xaxis = []
      i = 0
      groups.each { |group| xaxis << group }

      #Paid
      query = "select sum(rtfs.amount) AS amount,  fsa.#{grouping_col} AS #{grouping_col} from request_transactions rt, request_transaction_funding_sources rtfs, request_funding_sources rfs, #{temp_table_name} fsa, requests r
        WHERE #{always_exclude} AND rt.state in #{paid_states} AND rt.id = rtfs.request_transaction_id AND rfs.id = rtfs.request_funding_source_id AND fsa.id = rfs.funding_source_allocation_id AND r.id = rt.request_id
        AND r.grant_agreement_at >= ? AND r.grant_agreement_at <= ? AND fsa.#{grouping_col} IN (?) and rt.deleted_at is null GROUP BY fsa.#{grouping_col}"
      paid = ReportUtility.query_map_to_array([query, start_date, stop_date, ids], ids, grouping_col.to_sym, :amount)

      #Budgeted
      query = "SELECT SUM(tmp.amount) AS amount, tmp.#{grouping_col} AS #{grouping_col} FROM #{temp_table_name} tmp WHERE tmp.deleted_at IS NULL AND tmp.#{grouping_col} IN (?) AND tmp.spending_year IN (?) GROUP BY tmp.#{grouping_col}"
      budgeted = ReportUtility.query_map_to_array([query, ids, years], ids, grouping_col.to_sym, :amount)

      #Pipeline
      #TODO: Check this
      query = "SELECT SUM(r.amount_requested) AS amount, r.#{grouping_col} as #{grouping_col} FROM requests r  WHERE #{always_exclude} AND r.granted = 0 AND r.#{grouping_col} IN (?) AND r.state NOT IN (?) GROUP BY r.#{grouping_col}"
      pipeline = ReportUtility.query_map_to_array([query, ids, ReportUtility.pre_pipeline_states], ids, grouping_col.to_sym, :amount)

      hash = {:library => "jqPlot"}

      xaxis.each_index{|i| xaxis[i] = xaxis[i].to_s + "  #{(((total_grant_allocations[i].to_f + pipeline[i].to_f)/ budgeted[i].to_f) * 100).round.to_s rescue '0'}%"}
      budgeted.each_index{|i| budgeted[i] = 0 unless budgeted[i] }

      paid.each_index{|i| paid[i] = 0 unless paid[i] }

      if grouping_table == "programs"
        #Total Granted
        query = "SELECT sum(amount_recommended) as amount, #{grouping_col} FROM requests r WHERE #{always_exclude} AND granted = 1 AND grant_agreement_at >= ? AND grant_agreement_at <= ? AND #{grouping_col} IN (?) GROUP BY #{grouping_col}"
        total_granted = ReportUtility.query_map_to_array([query, start_date, stop_date, ids], ids, grouping_col.to_sym, :amount)
        hash[:data] = ReportUtility.convert_bigdecimal_to_f_in_array [pipeline, total_granted, budgeted, paid ]
        hash[:series] = [ {:label => "Pipeline", :renderer => "$.jqplot.BarRenderer"}, {:label => "Granted (By #{grouping_table.singularize.humanize})", :renderer => "$.jqplot.BarRenderer"}, {:label => "Allocated"}, {:label => "Paid"} ]
      else
        #Total Grant Allocations
        query = "SELECT SUM(rfs.funding_amount) AS amount, fsa.#{grouping_col} FROM requests r, request_funding_sources rfs, #{temp_table_name} fsa
          WHERE rfs.request_id = r.id and fsa.id = rfs.funding_source_allocation_id AND
          #{always_exclude} AND granted = 1 AND grant_agreement_at >= ? AND grant_agreement_at <= ? AND fsa.#{grouping_col} IN (?) GROUP BY fsa.#{grouping_col}"
        total_grant_allocations = ReportUtility.query_map_to_array([query, start_date, stop_date, ids], ids, grouping_col.to_sym, :amount)
        hash[:data] = ReportUtility.convert_bigdecimal_to_f_in_array [pipeline, total_grant_allocations, budgeted, paid ]
        hash[:series] = [ {:label => "Pipeline", :renderer => "$.jqplot.BarRenderer"}, {:label => "Granted (By Initiative)", :renderer => "$.jqplot.BarRenderer"}, {:label => "Allocated"}, {:label => "Paid"} ]
      end
      hash[:axes] = { :xaxis => {:ticks => xaxis, :tickOptions => { :angle => -30 }}, :yaxis => { :min => 0, :tickOptions => { :formatString => "#{I18n.t 'number.currency.format.unit'}%'.0f" }}}
      hash[:stackSeries] = true;
      hash[:type] = "line"
    end
    hash.to_json
  end

  #------------------------------------------------------------------------------------------------------------------------------------------------------

  def get_grouping_parameters filter
    if filter["active_record_base"]["program_id"]
      ids = ReportUtility.get_program_ids(filter["active_record_base"]["program_id"]) || []
      grouping_table = "programs"
      grouping_col  = "program_id"
    else
      ids = ReportUtility.get_initiative_ids(filter["active_record_base"]["initiative_id"]) || []
      grouping_table = "initiatives"
      grouping_col  = "initiative_id"
    end
    p [ids, grouping_table, grouping_col]
    [ids, grouping_table, grouping_col]
  end

  def get_date_range filter
    start_string = '1/1/' + filter["funding_year"] if filter && filter["funding_year"]
    start_date = if start_string
      Date.parse(start_string)
    else
      Time.at(0).to_date
    end
    return start_date, start_date.end_of_year()
  end

  def report_filter_text controller, index_object, params, report_vars, models
    start_date, stop_date = get_date_range params["active_record_base"]
    stop_date = Time.now if (stop_date > Time.now.to_date)
    "#{start_date.strftime('%B %d, %Y')} to #{stop_date.strftime('%B %d, %Y')}"
  end

  def report_summary controller, index_object, params, report_vars, models
    filter = params["active_record_base"]
    ids, grouping_table, grouping_col = get_grouping_parameters params
    start_date, stop_date = get_date_range filter
    query = "SELECT id FROM requests WHERE deleted_at IS NULL AND state <> 'rejected' and granted = 1 and grant_agreement_at >= ? and grant_agreement_at <= ? and #{grouping_col} in (?)"
    request_ids = ReportUtility.array_query([query, start_date, stop_date, ids])
    hash = ReportUtility.get_report_totals request_ids
    summary_text = "#{hash[:grants]} Grants totaling #{number_to_currency(hash[:grants_total])}"
    summary_text = summary_text + " and #{hash[:fips]} #{I18n.t(:fip_name).pluralize} totaling #{number_to_currency(hash[:fips_total])}" unless Fluxx.config(:hide_fips) == "1"
    summary_text
  end

  def report_legend controller, index_object, params, report_vars, models
    filter = params["active_record_base"]
    start_date, stop_date = get_date_range filter
    years = ReportUtility.get_years start_date, stop_date
    ids, grouping_table, grouping_col = get_grouping_parameters params
    always_exclude = "r.deleted_at IS NULL AND r.state <> 'rejected'"
    legend_table = ["Status", "Grants", "Grant #{CurrencyHelper.current_long_name.pluralize}"]
    legend_table = legend_table.concat [I18n.t(:fip_name).pluralize, "#{I18n.t(:fip_name)} #{CurrencyHelper.current_long_name.pluralize}"] unless Fluxx.config(:hide_fips) == "1"
    legend = [{:table => legend_table, :filter => "", :listing_url => "", :card_title => ""}]

    categories = {:pipeline => "Pipeline", :allocated => "Allocated", :paid => "Paid"}
    if grouping_table == "programs"
      categories[:granted_by_group] = "Granted (By Program)"
    else
      categories[:granted_by_initiative] = "Granted (By Initiative)"
    end
    start_date_string = start_date.strftime('%m/%d/%Y')
    stop_date_string = stop_date.strftime('%m/%d/%Y')
    FundingSourceAllocation.build_temp_table do |temp_table_name|
      categories.each do |k, group|
        card_filter = ""
        card_title = group
        listing_url = controller.granted_requests_path
        case k
          when :granted_by_group
            query = "SELECT SUM(r.amount_recommended) AS amount, count(r.id) AS count FROM requests r WHERE #{always_exclude} AND granted = 1 AND grant_agreement_at >= ? AND grant_agreement_at <= ? AND #{grouping_col} IN (?) AND type = ?"
            grant = [query, start_date, stop_date, ids, 'GrantRequest']
            fip = [query, start_date, stop_date, ids, 'FipRequest']
            card_filter ="utf8=%E2%9C%93&request%5Bdate_range_selector%5D=funding_agreement&request%5Brequest_from_date%5D=#{start_date_string}&request%5Brequest_to_date%5D=#{stop_date_string}&request%5B2has_been_rejected%5D=&request%5Bsort_attribute%5D=updated_at&request%5Bsort_order%5D=desc&request[#{grouping_col}][]=" + ids.join("&request[#{grouping_col}][]=")

          when :granted_by_initiative
            query = "SELECT SUM(rfs.funding_amount) AS amount, count(distinct r.id) AS count FROM requests r, request_funding_sources rfs, #{temp_table_name} fsa
              WHERE rfs.request_id = r.id and fsa.id = rfs.funding_source_allocation_id AND
              #{always_exclude} AND granted = 1 AND grant_agreement_at >= ? AND grant_agreement_at <= ? AND fsa.#{grouping_col} IN (?) AND type = ?
              "
            grant = [query, start_date, stop_date, ids, 'GrantRequest']
            fip = [query, start_date, stop_date, ids, 'FipRequest']
            card_filter ="utf8=%E2%9C%93&request%5Bdate_range_selector%5D=funding_agreement&request%5Brequest_from_date%5D=#{start_date_string}&request%5Brequest_to_date%5D=#{stop_date_string}&request%5B2has_been_rejected%5D=&request%5Bsort_attribute%5D=updated_at&request%5Bsort_order%5D=desc&request[funding_source_allocation_#{grouping_col}][]=" + ids.join("&request[funding_source_allocation_#{grouping_col}][]=")
          when :paid
            query = "select sum(rtfs.amount) AS amount, COUNT(DISTINCT r.id) AS count from request_transactions rt, request_transaction_funding_sources rtfs, request_funding_sources rfs, #{temp_table_name} fsa, requests r
              WHERE #{always_exclude} AND rt.state = 'paid' AND rt.id = rtfs.request_transaction_id AND rfs.id = rtfs.request_funding_source_id AND fsa.id = rfs.funding_source_allocation_id AND r.id = rt.request_id
              AND r.grant_agreement_at >= ? AND r.grant_agreement_at <= ? AND fsa.#{grouping_col} IN (?) AND type = ? and rt.deleted_at is null"
            grant = [query, start_date, stop_date, ids, 'GrantRequest']
            fip = [query, start_date, stop_date, ids, 'FipRequest']
          when :allocated
            query = "SELECT SUM(tmp.amount) AS amount FROM #{temp_table_name} tmp WHERE tmp.deleted_at IS NULL AND tmp.#{grouping_col} IN (?) AND tmp.spending_year IN (?)"
            grant = [query, ids, years]
            fip = [query, ids, years]
          when :pipeline
            query = "SELECT SUM(r.amount_requested) AS amount, COUNT(DISTINCT r.id) AS count FROM requests r  WHERE #{always_exclude} AND r.granted = 0 AND r.#{grouping_col} IN (?) AND type = ? AND r.state NOT IN (?)"
            grant = [query, ids, 'GrantRequest', ReportUtility.pre_pipeline_states]
            fip = [query, ids, 'FipRequest', ReportUtility.pre_pipeline_states]
            filter_states = "&request[filter_state][]=" + (GrantRequest.all_states).select{|state| ReportUtility.pre_pipeline_states.index(state.to_s).nil? }.join("&request[filter_state][]=")
            card_filter ="utf8=%E2%9C%93&request%5Bsort_attribute%5D=updated_at&request%5Bsort_order%5D=desc&request[#{grouping_col}][]=" + ids.join("&request[#{grouping_col}][]=") + filter_states
            listing_url = controller.grant_requests_path
        end
        grant_result = ReportUtility.single_value_query(grant)
        fip_result = ReportUtility.single_value_query(fip)
        legend_table = [group, grant_result[:count], number_to_currency(grant_result[:amount] ? grant_result[:amount] : 0 )]
        legend_table = legend_table.concat [fip_result[:count], number_to_currency(fip_result[:amount] ? fip_result[:amount] : 0)] unless Fluxx.config(:hide_fips) == "1"
        legend << { :table => legend_table, :filter => card_filter, :listing_url => listing_url, :card_title => card_title}
      end
    end
   legend
  end
end