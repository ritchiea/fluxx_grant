module BudgetOverviewBaseReport
  def compute_plot_data controller, index_object, params, report_vars, models
    filter = params["active_record_base"]
    hash = {:library => "jqPlot", :title => index_object.report_label}
    ids, grouping_table, grouping_col = get_grouping_parameters params
    data = calculate_report_data filter


    #Calculate Series
    #Paid
    paid = ids.map{|id| data[:fsa_query].select{|fsa| (grouping_table == "programs" ? fsa.derive_program.id : fsa.derive_initiative.id) == id}.inject(0){|acc, rfs| acc + (rfs.amount_paid || 0)}}

    #Pipeline
    pipeline = ids.map{|id| data[:fsa_query].select{|fsa| (grouping_table == "programs" ? fsa.derive_program.id : fsa.derive_initiative.id) == id}.inject(0){|acc, rfs| acc + (rfs.amount_granted_in_queue || 0)}}

    #Granted
    granted = ids.map{|id| data[:fsa_query].select{|fsa| (grouping_table == "programs" ? fsa.derive_program.id : fsa.derive_initiative.id) == id}.inject(0){|acc, rfs| acc + (rfs.amount_granted || 0)}}

    #Allocated
    allocated = ids.map{|id| data[:fsa_query].select{|fsa| (grouping_table == "programs" ? fsa.derive_program.id : fsa.derive_initiative.id) == id}.inject(0){|acc, rfs| acc + (rfs.amount || 0)}}

    #Construct AXIS labels
    query = "SELECT name, id FROM #{grouping_table} WHERE id IN (?)"
    xaxis = ReportUtility.query_map_to_array([query, ids], ids, :id, :name)
    xaxis = xaxis.each_index{|i| xaxis[i] = xaxis[i].to_s + "  #{(((granted[i].to_f + pipeline[i].to_f)/ allocated[i].to_f) * 100).round.to_s rescue '0'}%"}

    #Send out chart data
    hash[:axes] = { :xaxis => {:ticks => xaxis, :tickOptions => { :angle => -30 }}, :yaxis => { :min => 0, :tickOptions => { :formatString => "#{I18n.t 'number.currency.format.unit'}%'.0f" }}}
    hash[:stackSeries] = true;
    hash[:type] = "line"
    hash[:data] = ReportUtility.convert_bigdecimal_to_f_in_array [pipeline, granted, allocated, paid ]
    hash[:series] = [ {:label => "Pipeline", :renderer => "$.jqplot.BarRenderer"}, {:label => "Granted", :renderer => "$.jqplot.BarRenderer"}, {:label => "Allocated", :disableStack => true}, {:label => "Paid", :disableStack => true} ]
    hash.to_json
  end

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
    data = calculate_report_data filter
    ids, grouping_table, grouping_col = get_grouping_parameters params
    start_date, stop_date = get_date_range filter
    num_grants = data[:grant_pipeline_count] + data[:grant_granted_count] + data[:grant_paid_count]
    num_fips = data[:fip_pipeline_count] + data[:fip_granted_count] + data[:fip_paid_count]
    sum_grants = data[:grant_pipeline] + data[:grant_granted] + data[:grant_paid]
    sum_fips = data[:fip_pipeline] + data[:fip_granted] + data[:fip_paid]

    summary_text = "#{num_grants} Grants totaling #{(sum_grants || 0).to_currency(:precision => 0)}"
    summary_text = summary_text + " and #{num_fips} #{I18n.t(:fip_name).pluralize} totaling #{(sum_fips || 0).to_currency(:precision => 0)}" unless Fluxx.config(:hide_fips) == "1"
    summary_text
  end

  def report_legend controller, index_object, params, report_vars, models
    filter = params["active_record_base"]
    data = calculate_report_data filter
    start_date, stop_date = get_date_range filter
    years = ReportUtility.get_years start_date, stop_date
    ids, grouping_table, grouping_col = get_grouping_parameters params

    legend_table = ["Status", "Grants", "Grant #{CurrencyHelper.current_long_name.pluralize}"]
    legend_table = legend_table.concat [I18n.t(:fip_name).pluralize, "#{I18n.t(:fip_name)} #{CurrencyHelper.current_long_name.pluralize}"] unless Fluxx.config(:hide_fips) == "1"
    legend = [{:table => legend_table, :filter => "", :listing_url => "", :card_title => ""}]

    categories = [:granted, :pipeline, :allocated, :paid]
    start_date_string = start_date.strftime('%m/%d/%Y')
    stop_date_string = stop_date.strftime('%m/%d/%Y')

    categories.each do |cat|
      card_filter = ""
      card_title = cat.to_s.humanize
      listing_url = controller.granted_requests_path
      case cat
        when :granted
          grant_result = data[:grant_granted]
          fip_result = data[:fip_granted]
          card_filter ="utf8=%E2%9C%93&request%5Bdate_range_selector%5D=funding_agreement&request%5Brequest_from_date%5D=#{start_date_string}&request%5Brequest_to_date%5D=#{stop_date_string}&request%5B2has_been_rejected%5D=&request%5Bsort_attribute%5D=updated_at&request%5Bsort_order%5D=desc&request[#{grouping_col}][]=" + ids.join("&request[#{grouping_col}][]=")
          grant_count = data[:grant_granted_count]
          fip_count = data[:fip_granted_count]
        when :paid
          grant_result = data[:grant_paid]
          fip_result = data[:fip_paid]
          grant_count = data[:grant_paid_count]
          fip_count = data[:fip_paid_count]
        when :allocated
          grant_result = data[:allocated]
        when :pipeline
          grant_result = data[:grant_pipeline]
          fip_result = data[:fip_pipeline]
          grant_count = data[:grant_pipeline_count]
          fip_count = data[:fip_pipeline_count]
          listing_url = controller.grant_requests_path
          filter_states = "&request[filter_state][]=" + (GrantRequest.all_states).select{|state| ReportUtility.pre_pipeline_states.index(state.to_s).nil? }.join("&request[filter_state][]=")
          card_filter ="utf8=%E2%9C%93&request%5Bsort_attribute%5D=updated_at&request%5Bdate_range_selector%5D=funding_agreement&request%5Brequest_from_date%5D=#{start_date_string}&request%5Brequest_to_date%5D=#{stop_date_string}%5Bsort_order%5D=desc&request[#{grouping_col}][]=" + ids.join("&request[#{grouping_col}][]=") + filter_states
      end
      if cat == :allocated
        legend_table = [card_title, {:value => (grant_result || 0).to_currency(:precision => 0), :colspan => 4}]
        legend << { :table => legend_table, :filter => card_filter, :listing_url => listing_url, :card_title => card_title}
      else
        legend_table = [card_title, grant_count, (grant_result || 0).to_currency(:precision => 0)]
        legend_table = legend_table.concat [fip_count, (fip_result || 0).to_currency(:precision => 0)] unless Fluxx.config(:hide_fips) == "1"
        legend << { :table => legend_table, :filter => card_filter, :listing_url => listing_url, :card_title => card_title}
      end
    end
   legend
  end

  def calculate_report_data params
    # AML: Because reports use a singleton class we can't use an instance variable and be threadsafe.
    #      For now I'm storing our cached data in the params hash.
    report_data = params[:report_data]
    unless report_data
      report_data = {:allocated => 0, :grant_pipeline => 0, :fip_pipeline => 0, :grant_pipeline_count => 0, :fip_pipeline_count => 0, :grant_granted => 0, :fip_granted => 0,
      :grant_paid => 0, :fip_paid => 0, :available => 0, :budgeted => 0, :forecast => 0, :grant_granted_count => 0, :fip_granted_count => 0, :grant_paid_count => 0, :fip_paid_count => 0}
      fsa_query = FundingSourceAllocation.find_by_category(params).where(:spending_year => params[:funding_year])
      report_data[:fsa_query] = fsa_query;
      fsa_query.each do |funding_source_allocation_model|
        if funding_source_allocation_model.funding_source
          if funding_source_allocation_model.funding_source.is_approved?
            report_data[:allocated] += (funding_source_allocation_model.amount || 0)

            report_data[:grant_pipeline] += (funding_source_allocation_model.amount_granted_in_queue("GrantRequest") || 0)
            report_data[:fip_pipeline_count] += (funding_source_allocation_model.number_granted_in_queue("FipRequest") || 0)
            report_data[:grant_pipeline_count] += (funding_source_allocation_model.number_granted_in_queue("GrantRequest") || 0)
            report_data[:fip_pipeline] += (funding_source_allocation_model.amount_granted_in_queue("FipRequest") || 0)

            report_data[:grant_granted] += (funding_source_allocation_model.amount_granted("GrantRequest") || 0)
            report_data[:fip_granted] += (funding_source_allocation_model.amount_granted("FipRequest") || 0)
            report_data[:grant_granted_count] += (funding_source_allocation_model.number_granted("GrantRequest") || 0)
            report_data[:fip_granted_count] += (funding_source_allocation_model.number_granted("FipRequest") || 0)

            report_data[:grant_paid] += (funding_source_allocation_model.amount_paid("GrantRequest") || 0)
            report_data[:fip_paid] += (funding_source_allocation_model.amount_paid("FipRequest") || 0)
            report_data[:grant_paid_count] += (funding_source_allocation_model.number_paid("GrantRequest") || 0)
            report_data[:fip_paid_count] += (funding_source_allocation_model.number_paid("FipRequest") || 0)

            report_data[:available] += (funding_source_allocation_model.amount_remaining || 0) - (funding_source_allocation_model.amount_granted_in_queue || 0)
          end
          report_data[:budgeted] += (funding_source_allocation_model.budget_amount || 0) # Budgeting should be summed regardless of whether it's approved
          report_data[:forecast] += (funding_source_allocation_model.actual_budget_amount || 0) # Actual should be summed regardless of whether it's approved
        end
      end
      params[:report_data] = report_data
    end
    report_data
  end

end