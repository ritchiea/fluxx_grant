module FluxxInitiative
  def self.included(base)
    base.belongs_to :program
    base.acts_as_audited :protect => true

    base.validates_presence_of     :program
    base.validates_presence_of     :name
    base.validates_length_of       :name,    :within => 3..255
    
    base.extend(ModelClassMethods)
    base.class_eval do
      include ModelInstanceMethods
    end
  end

  module ModelClassMethods
  end

  module ModelInstanceMethods
    def to_s
      name
    end
  end
end