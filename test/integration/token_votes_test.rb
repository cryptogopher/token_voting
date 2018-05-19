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

    # cannot create without logging in
    assert_no_difference 'TokenVote.count' do
      post "#{issue_token_votes_path(issue)}.js", params: {
        token_vote: { token: 'BTCREG', duration: 1.day }
      }
    end
    assert_response :unauthorized

    # cannot create without permissions
    log_user 'alice', 'foo'
    role.remove_permission! :manage_token_votes
    assert_no_difference 'TokenVote.count' do
      post "#{issue_token_votes_path(issue)}.js", params: {
        token_vote: { token: 'BTCREG', duration: 1.day }
      }
    end
    assert_response :forbidden

    # can create
    role.add_permission! :manage_token_votes
    assert_difference 'TokenVote.count', 1 do
      post "#{issue_token_votes_path(issue)}.js", params: {
        token_vote: { token: 'BTCREG', duration: 1.day }
      }
      assert_nil flash[:error]
    end
    assert_response :ok
  end

  def test_destroy_only_if_authorized_and_deletable
  end
end

