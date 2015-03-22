module EmailIntegration
  module MailHandlerPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)
      
      base.class_eval do
        alias_method_chain :dispatch, :email_integration
      end
    end
    
    module InstanceMethods
      private

      MESSAGE_ID_RE = %r{^<?redmine\.([a-z0-9_]+)\-(\d+)\.\d+(\.[a-f0-9]+)?@}
      ISSUE_REPLY_SUBJECT_RE = %r{\[(?:[^\]]*\s+)?#(\d+)\]}
      MESSAGE_REPLY_SUBJECT_RE = %r{\[[^\]]*msg(\d+)\]}

      def dispatch_with_email_integration
        # タイトルに特定のパターンにマッチしたら
        # デフォルトアクションに処理してもらう
        headers = [email.in_reply_to, email.references].flatten.compact
        subject = email.subject.to_s
        if headers.detect {|h| h.to_s =~ MESSAGE_ID_RE} || subject.match(ISSUE_REPLY_SUBJECT_RE) || subject.match(MESSAGE_REPLY_SUBJECT_RE)
          dispatch_without_email_integration
          return
        end

        origin_message_id = email.references.first if email.references.class == Array
        origin_message_id = email.in_reply_to unless origin_message_id

        # New email
        unless origin_message_id
          # Prevent duplicate ticket creation
          # Example:
          #   to: a@example.com
          #   cc: alias_has_a@example.com
          origin_message = EmailMessage.find_by message_id: email.message_id
          return if origin_message

          # Create new issue
          issue = receive_issue
          issue.description = email_details + issue.description
          issue.save
          current_email_message            = EmailMessage.new
          current_email_message.issue_id   = issue.id
          current_email_message.message_id = email.message_id
          current_email_message.save
          return issue
        end

        # Reply mail
        #  - Save journal if associated message-id exists
        origin_message = EmailMessage.find_by message_id: origin_message_id
        unless origin_message
          # ignore
        else
          journal = receive_issue_reply(origin_message.issue_id)
          journal.notes = email_details + email_reply_collapse(journal.notes)
          journal.save
          journal
        end
      end

      def email_details
        email_details = "From: " + @email[:from].formatted.first + "\n"
        email_details << "To: " + @email[:to].formatted.join(', ') + "\n"
        if !@email.cc.nil?
          email_details << "Cc: " + @email[:cc].formatted.join(', ') + "\n"
        end
        email_details << "Date: " + @email[:date].to_s + "\n"
        "<pre>\n" + Mail::Encodings.unquote_and_convert_to(email_details, 'utf-8') + "</pre>"
      end

      def email_reply_collapse(notes)

        # Email "Origianl Message" Patterns
        patterns = [

          # Gamil
          # 2015-3-22 10:52 Taro Example <taro@example.com>:
          %r{^\d{4}-\d{1,2}-\d{1,2} [0-9]{1,2}:[0-9]{1,2}.*<[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}>:(?m).*},

          # Gamil(ja)
          # 2015年3月22日 10:52 Taro Example <taro@example.com>:
          %r{^\d{4}年\d{1,2}月\d{1,2}日 [0-9]{1,2}:[0-9]{1,2}.*<[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}>:(?m).*},

          # Outlook/Outlook Express
          # -----Original Message-----
          %r{^[-]*[\s]*Original Message[\s]*[-]*(?m).*},

          # Outlook/Outlook Express(ja)
          # -----元のメッセージ-----
          %r{^[-]*[\s]*元のメッセージ[\s]*[-]*(?m).*},

          # Thunderbird
          # (2014/08/05 3:51), Taro Example wrote:
          %r{\([0-9]{4}\/[0-9]{1,2}\/[0-9]{1,2} [0-9]{1,2}:[0-9]{1,2}\).*wrote:(?m).*},

          # Thunderbird(old ja)
          # (2014/08/05 3:51), Taro Example wrote:
          %r{\([0-9]{4}\/[0-9]{1,2}\/[0-9]{1,2} [0-9]{1,2}:[0-9]{1,2}\).*書きました:(?m).*}

        ]
        patterns.each do |pattern|
          binding.pry
          if notes =~ pattern
            notes = notes.gsub(pattern,"{{collapse(Read More...)\r\n \\0\r\n}}")
            return notes
          end
        end
        notes
      end

    end # module InstanceMethods
  end # module MailHandlerPatch
end # module EmailEntegration

# Add module to MailHandler class
MailHandler.send(:include, EmailIntegration::MailHandlerPatch)

