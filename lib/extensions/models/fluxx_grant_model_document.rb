module FluxxGrantModelDocument
  extend FluxxModuleHelper

  when_included do
    include FluxxModelDocument
  end
  
  class_methods do
    # This pretty much applies to the board user.  If this is a board user, we want to limit them to seeing report sections based on their doc_label
    def relates_to_class? user, options={}
      doc_label = options[:doc_label]
      Fluxx.config("documents_allowed_#{doc_label}_#{user && user.user_profile && user.user_profile.name}")
    end
    
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
  
  instance_methods do
  end
end
