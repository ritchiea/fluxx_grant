class FluxxGrantAddOldValueFieldsToRequestAmendmentsTable < ActiveRecord::Migration
  def self.up
    change_table :request_amendments do |t|
      t.integer :old_duration
      t.datetime :old_start_date
      t.datetime :old_end_date
      t.decimal :old_amount_recommended, :scale => 2, :precision => 15
    end
  end

  def self.down
    change_table :request_amendments do |t|
      t.remove :old_duration
      t.remove :old_start_date
      t.remove :old_end_date
      t.remove :old_amount_recommended
    end
  end
end