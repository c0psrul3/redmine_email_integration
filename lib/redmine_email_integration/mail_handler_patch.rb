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
        # Prevent duplicate ticket creation
        if EmailMessage.message_id_exists?(email.message_id)
          logger.debug "[redmine_email_integration] Ignore duplicate email" if logger && logger.debug?
          return false
        end

        # Default action if subject has special keywords
        # ex) [#id]
        headers = [email.in_reply_to, email.references].flatten.compact
        subject = email.subject.to_s
        if headers.detect {|h| h.to_s =~ MESSAGE_ID_RE} || subject.match(ISSUE_REPLY_SUBJECT_RE) || subject.match(MESSAGE_REPLY_SUBJECT_RE)
          logger.debug "[redmine_email_integration] Delegate to redmine default method" if logger && logger.debug?
          result = dispatch_without_email_integration
          save_message_id(email.message_id)
          return result
        end

        origin_message_id = email.references.first if email.references.class == Array
        origin_message_id = email.in_reply_to unless origin_message_id

        unless origin_message_id
          # New mail
          issue = receive_issue
          issue.description = email_details + email_body_collapse(issue.description)
          if issue.save
            save_message_id(email.message_id, issue.id)
            logger.debug "[redmine_email_integration] Save new mail as issue" if logger && logger.debug?
          end
          return issue
        else
          # Reply mail
          origin_message = EmailMessage.find_by(message_id: origin_message_id)
          if origin_message.nil?
            logger.debug "[redmine_email_integration] This is reply mail but original message-id not found" if logger && logger.debug?
            return false
          end

          logger.debug "[redmine_email_integration] Original message-id: #{origin_message.message_id}" if logger && logger.debug?

          journal = receive_issue_reply(origin_message.issue_id)
          journal.notes = email_details + email_body_collapse(journal.notes)
          if journal.save
            save_message_id(email.message_id)
            logger.debug "[redmine_email_integration] Save reply mail as journal" if logger && logger.debug?
          end
          return journal
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

      def email_body_collapse(notes)

        # Email "Origianl Message" Patterns
        patterns = [

          # 2015-3-22 10:52 Taro Example <taro@example.com>:
          %r{^[> ]*\d{4}-\d{1,2}-\d{1,2} [0-9]{1,2}:[0-9]{1,2}.*<[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}>:(?m).*},

          # 2015年3月22日 10:52 Taro Example <taro@example.com>:
          %r{^[> ]*\d{4}年\d{1,2}月\d{1,2}日 [0-9]{1,2}:[0-9]{1,2}.*<[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}>:(?m).*},

          # From: Taro Example <taro@example.com>
          %r{^[> ]*From:.*[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}(?m).*},

          # -----Original Message-----
          %r{^[> ]*[-]*[\s]*Original Message[\s]*[-]*(?m).*},

          # -----元のメッセージ-----
          %r{^[> ]*[-]*[\s]*元のメッセージ[\s]*[-]*(?m).*},

          # (2014/08/05 3:51), Taro Example wrote:
          %r{^[> ]*\([0-9]{4}\/[0-9]{1,2}\/[0-9]{1,2} [0-9]{1,2}:[0-9]{1,2}\).*wrote:(?m).*},

          # (2014/08/05 3:51), Taro Example wrote:
          %r{^[> ]*\([0-9]{4}\/[0-9]{1,2}\/[0-9]{1,2} [0-9]{1,2}:[0-9]{1,2}\).*書きました:(?m).*},

          # -----転送メッセージ-----
          %r{^[> ]*[-]*[\s]*転送メッセージ[\s]*[-]*(?m).*},

          # -------- Forwarded Message --------
          %r{^[> ]*[-]*[\s]*Forwarded Message[\s]*[-]*(?m).*}

        ]
        patterns.each do |pattern|
          if notes =~ pattern
            notes = notes.sub(pattern,"{{collapse(Read More...)\r\n \\0\r\n}}")
            return notes
          end
        end
        notes
      end

      def save_message_id(message_id, issue_id=nil)
        return false unless message_id 

        message            = EmailMessage.new
        message.message_id = message_id
        message.issue_id   = issue_id if issue_id
        message.save
      end

    end # module InstanceMethods
  end # module MailHandlerPatch
end # module EmailEntegration

# Add module to MailHandler class
MailHandler.send(:include, EmailIntegration::MailHandlerPatch)

