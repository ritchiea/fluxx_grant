class Ofac
  def generate_csv models, output
    if models
      csv = FasterCSV.new(output, :row_sep => "\r\n") 
      models.each do |model|
        if model.is_a? User
          csv << [model.title,
                  model.first_name,
                  model.middle_initial,
                  model.last_name,
                  '', # Gender
                  model.id,
                  '', #ssn
                  model.personal_street_address,
                  model.personal_street_address2,
                  model.personal_city,
                  model.personal_state_name,
                  model.personal_postal_code,
                  model.personal_country_name,
                  model.personal_phone,
                  model.work_phone,  # office phone
                  model.personal_mobile,
                  model.work_fax ,
                  model.birth_at ? model.birth_at.mdy : ''
            ]
        elsif model.is_a? Organization
          csv << [model.name,
                  model.id,
                  model.tax_id,
                  model.street_address,
                  model.street_address2,
                  model.city,
                  model.state_name,
                  model.postal_code,
                  model.country_name,
                  model.phone,
                  model.fax
            ]
        end
      end
      csv.close
    end
  end
end