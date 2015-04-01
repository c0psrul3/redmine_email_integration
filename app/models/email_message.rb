class EmailMessage < ActiveRecord::Base
  unloadable

  attr_accessible :issue_id,
                  :message_id

  validates :message_id, presence: true

  def self.message_id_exists?(message_id)
    self.exists?(message_id: message_id)
  end
end

