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

        binding.pry

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
          current_email_message            = EmailMessage.new
          current_email_message.issue_id   = issue.id
          current_email_message.message_id = email.message_id
          current_email_message.save
          return issue
        end

        # Reply mail
        #  - Save journal if associated message-id exists
        origin_message = EmailMessage.find_by message_id: origin_message_id
        if origin_message
          receive_issue_reply(origin_message.issue_id)
        else
          # ignore
        end
      end

    end # module InstanceMethods
  end # module MailHandlerPatch
end # module EmailEntegration

# Add module to MailHandler class
MailHandler.send(:include, EmailIntegration::MailHandlerPatch)

