require File.expand_path('../../test_helper', __FILE__)

class EmailMessageTest < ActiveSupport::TestCase
  include Redmine::I18n

  self.use_transactional_fixtures = true

  fixtures :projects, :projects_trackers,
           :issues, :issue_statuses, :trackers,
           :journals, :journal_details,
           :attachments,
           :members, :member_roles,
           :roles,
           :users,
           :enumerations

  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures/mail_handler'

  def setup
    ActionMailer::Base.deliveries.clear
    Setting.notified_events = Redmine::Notifiable.all.collect(&:name)
  end

  def teardown
    Setting.clear_cache
  end

  def test_add_issue_with_email_reply
    issue = submit_email('new_email.eml',
                         :issue => {:project => 'email_integration_project_1'},
                         :unknown_user => 'accept',
                         :no_permission_check => 1)
    assert_issue_created issue
    journal = submit_email('email_reply.eml',
                         :issue => {:project => 'email_integration_project_1'},
                         :unknown_user => 'accept',
                         :no_permission_check => 1)
    assert journal.is_a?(Journal)
    assert_equal journal.id, issue.journals.last.id
  end

  def test_prevent_duplicate_issue
    issue1 = submit_email('new_email.eml',
                         :issue => {:project => 'email_integration_project_1'},
                         :unknown_user => 'accept',
                         :no_permission_check => 1)
    assert_issue_created issue1
    issue2 = submit_email('new_email.eml',
                         :issue => {:project => 'email_integration_project_1'},
                         :unknown_user => 'accept',
                         :no_permission_check => 1)
    assert_equal false, issue2
  end

  def test_issue_id_in_title
    issue = submit_email('issue_id_in_title.eml',
                         :issue => {:project => 'email_integration_project_1'},
                         :unknown_user => 'accept',
                         :no_permission_check => 1)
    assert_issue_created issue
  end

  def test_prevent_duplicate_reply
    issue = submit_email('new_email.eml',
                         :issue => {:project => 'email_integration_project_1'},
                         :unknown_user => 'accept',
                         :no_permission_check => 1)
    assert_issue_created issue
    journal1 = submit_email('email_reply.eml',
                         :issue => {:project => 'email_integration_project_1'},
                         :unknown_user => 'accept',
                         :no_permission_check => 1)
    assert journal1.is_a?(Journal)
    assert_equal journal1.id, issue.journals.last.id
    journal2 = submit_email('email_reply.eml',
                         :issue => {:project => 'email_integration_project_1'},
                         :unknown_user => 'accept',
                         :no_permission_check => 1)
    assert_equal false, journal2
  end

  private

    def submit_email(filename, options={})
      raw = IO.read(File.join(FIXTURES_PATH, filename))
      yield raw if block_given?
      MailHandler.receive(raw, options)
    end

    def assert_issue_created(issue)
      assert issue.is_a?(Issue)
      assert !issue.new_record?
      issue.reload
    end
end

