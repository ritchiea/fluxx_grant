class FluxxGrantAddProgInitiativeBackInToRfs < ActiveRecord::Migration
  def self.up
    change_table :request_transactions do |t|
      t.integer :program_id, :sub_program_id, :initiative_id, :sub_initiative_id
    end
    
    add_constraint 'request_transactions', 'request_transactions_program_id', 'program_id', 'programs', 'id'
    add_constraint 'request_transactions', 'request_transactions_sub_program_id', 'sub_program_id', 'sub_programs', 'id'
    add_constraint 'request_transactions', 'request_transactions_initiative_id', 'initiative_id', 'initiatives', 'id'
    add_constraint 'request_transactions', 'request_transactions_sub_initiative_id', 'sub_initiative_id', 'sub_initiatives', 'id'
  end

  def self.down
    change_table :request_transactions do |t|
      t.remove :program_id, :sub_program_id, :initiative_id, :sub_initiative_id
    end
  end
end