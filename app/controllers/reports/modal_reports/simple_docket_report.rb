class SimpleDocketReport < ActionController::ReportBase
  insta_report(:show) do |insta|
    insta.filter_template = 'modal_reports/simple_docket_filter'
    insta.report_order = 2
    insta.report_label = 'Docket Content Generator'
    insta.report_description = 'Used to generate information for proposals under consideration for Board Approval (HTML/PDF)'
    insta.report_visible_block = lambda{|report, config| Fluxx.config(:show_simple_docket_report) == '1'}
  end

  def compute_document_data controller, show_object, params, report_vars, models
    active_record_params = params[:active_record_base] || {}
    
    doc_id = active_record_params[:doc_id]
    case active_record_params[:date_range_type]
    when 'this_week'
      start_date = Time.now.ago(7.days)
      end_date = Time.now
    when 'last_week'
      start_date = Time.now.ago(14.days)
      end_date = Time.now.ago(7.days)
    else
      start_date = if active_record_params[:start_date].blank?
        nil
      else
        Time.parse(active_record_params[:start_date]) rescue nil
      end || Time.now
      end_date = if active_record_params[:end_date].blank?
        nil
      else
        Time.parse(active_record_params[:end_date]) rescue nil
      end || Time.now
    end

    programs = active_record_params[:program_id]
    programs = if active_record_params[:program_id]
      Program.where(:id => active_record_params[:program_id]).all rescue nil
    end || []
    programs = programs.compact
    
    sub_programs = active_record_params[:sub_program_id]
    sub_programs = if active_record_params[:sub_program_id]
      SubProgram.where(:id => active_record_params[:sub_program_id]).all rescue nil
    end || []
    sub_programs = sub_programs.compact
    
    grant_cycle_id = active_record_params[:grant_cycle]
    grant_cycle = ModelAttributeValue.find grant_cycle_id rescue nil unless grant_cycle_id.blank?
    
    query = Request.scoped
    query = query.where(:deleted_at => nil)
    states = active_record_params[:state]
    query = query.where(:state => states) unless states.blank? || states.empty?
    query = query.where(['requests.grant_begins_at >= ?', start_date]) if start_date
    query = query.where(['requests.grant_begins_at <= ?', end_date]) if end_date
    query = query.where(:program_id => programs) unless programs.empty?
    query = query.where(:sub_program_id => sub_programs) unless sub_programs.empty?
    query = query.includes([:program, :sub_program, :program_organization])
    query = query.where_dyn_for('grant_cycle', grant_cycle) if grant_cycle
    requests = query.all
    
    header_output = StringIO.new
    body_output = StringIO.new
    footer_output = StringIO.new
    header_footer_params = {'start_date' => start_date, 'end_date' => end_date, 
       'programs' => (programs && !programs.empty? ? programs.map{|program| program.name}.join(", ") : nil), 
       'sub_programs' => (sub_programs && !sub_programs.empty? ? sub_programs.map{|sub_program| sub_program.name}.join(", ") : nil), 
       'grant_cycle' => (grant_cycle ? grant_cycle.to_s : nil)}

    body_docket = ModelDocumentTemplate.where(:id => doc_id).first
    if body_docket
      header_docket = ModelDocumentTemplate.where(:related_model_document_id => doc_id, :category => 'header').first
      footer_docket = ModelDocumentTemplate.where(:related_model_document_id => doc_id, :category => 'footer').first

      if header_docket
        header = header_docket.document
        header_output.write Liquid::Template.parse(header).render(header_footer_params)
      end
    
      if body_docket
        body = body_docket.document
        requests.each_with_index do |r, i|
          body_output.write Liquid::Template.parse(body).render('request' => r)
          unless requests.size - 1 == i
            body_output.write "<p class='page-break'>\n"
          end
        end
      end

      if footer_docket
        footer = footer_docket.document
        footer_output.write Liquid::Template.parse(footer).render(header_footer_params)
      end

    
      retval = header_output.string + body_output.string + footer_output.string
      retval
    end
  end
end