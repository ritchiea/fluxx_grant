class ModelDocument < ActiveRecord::Base
  include FluxxModelDocument

  def relates_to_user? user
    if (self.documentable.class.name == 'RequestReport')
      (user.primary_organization.id == self.documentable.request.program_organization_id) || (user.primary_organization.id == self.documentable.request.fiscal_organization_id)
    else
      if (current_user.is_portal_user?)
        self.created_by.is_portal_user? if self.created_by
      else
        false
      end
    end
  end

end