class FluxxGrantCreateRequestAmendment < ActiveRecord::Migration
  def self.up
    drop rescue nil

    create_table "request_amendments", :force => true do |t|
      t.timestamps
      t.integer :duration
      t.datetime :start_date
      t.datetime :end_date
      t.decimal :amount_recommended, :scale => 2, :precision => 10
      t.boolean :original, :default => false
      t.references :request, :polymorphic => true
    end
  end

  def self.down
    drop_table "request_amendments"
  end
end
