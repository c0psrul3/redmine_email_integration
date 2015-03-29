class EmailMessage < ActiveRecord::Base
  unloadable

  attr_accessible :issue_id,
                  :message_id

  validates :message_id, presence: true
end

