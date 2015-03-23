require 'redmine_email_integration/mail_handler_patch'

Redmine::Plugin.register :redmine_email_integration do
  name 'Redmine Email Integration plugin'
  author 'Noah Kobayashi'
  description "This plugin saves reply emails as ticket's notes."
  version '0.0.1'
  url 'https://github.com/vohedge/redmine_email_integration.git'
  author_url 'https://github.com/vohedge/redmine_email_integration.git'
end

