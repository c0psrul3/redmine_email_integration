class CreateEmailMessages < ActiveRecord::Migration
  def change
    create_table :email_messages do |t|
      t.column :issue_id, :integer, :default => 0, :null => true
      t.column :message_id, :string, :null => false
      t.timestamps :null => false
    end
  end
end

