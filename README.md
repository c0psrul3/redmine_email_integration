# Redmine Email Integration Plugin

This plugin saves "Message-ID" of email to associate an email with an issue/reply (journal).

Inspired by [redmine_mail_intergration](https://github.com/YusukeKokubo/redmine_mail_intergration).

## Installation

To install the plugin clone the repo from github and migrate the database:

    cd /path/to/redmine/
    git clone git://github.com/vohedge/redmine_email_integration.git plugins/redmine_email_integration
    rake redmine:plugins:migrate RAILS_ENV=production

To uninstall the plugin migrate the database back and remove the plugin:

    cd /path/to/redmine/
    rake redmine:plugins:migrate NAME=redmine_email_integration VERSION=0 RAILS_ENV=production
    rm -rf plugins/redmine_email_integration

Further information about plugin installation can be found at: http://www.redmine.org/wiki/redmine/Plugins

## Cronjob

Creating tickets from support emails through an IMAP-account is done by a cronjob. The following syntax is for ubuntu or debian linux:

    */5 * * * * redmine /usr/bin/rake -f /path/to/redmine/Rakefile --silent redmine:email:receive_imap RAILS_ENV="production" host=mail.example.com port=993 username=username password=password ssl=true project=project_identifier folder=INBOX move_on_success=processed move_on_failure=failed no_permission_check=1 unknown_user=accept 1 > /dev/null

Further information about receiving emails with redmine can be found at: http://www.redmine.org/projects/redmine/wiki/RedmineReceivingEmails

## Compatibility

Tested only Redmine 3.0

## License

Copyright (c) 2015 Noah Kobayashi
Released under the MIT license
http://opensource.org/licenses/mit-license.php

