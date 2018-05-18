require File.expand_path('../../test_helper', __FILE__)

class TokenVotesControllerTest < Redmine::IntegrationTest
  fixtures :issues, :issue_statuses, :users,
    :projects, :roles, :members, :member_roles, :enabled_modules

  def setup
    default_plugin_settings
  end

  def test_create_only_if_authorized_and_has_permissions
    issue = issues(:issue_01)
    role = users(:alice).members.find_by(project: issue.project_id).roles.first

    post "#{issue_token_votes_path(issue)}.js", params: {
      token_vote: { token: 'BTCREG', duration: 1.day }
    }
    #assert_redirected_to %r(\A#{signin_url}\?back_url=)
    assert_response :unauthorized

    log_user 'alice', 'foo'
    role.remove_permission! :manage_token_votes
    post "#{issue_token_votes_path(issue)}.js", params: {
      token_vote: { token: 'BTCREG', duration: 1.day }
    }
    assert_response :forbidden

    role.add_permission! :manage_token_votes
    post "#{issue_token_votes_path(issue)}.js", params: {
      token_vote: { token: 'BTCREG', duration: 1.day }
    }
    assert_response :ok
  end

  def test_create_if_authorized
  end
end

