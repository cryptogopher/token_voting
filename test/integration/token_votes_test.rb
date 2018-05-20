require File.expand_path('../../test_helper', __FILE__)

class TokenVotesControllerTest < Redmine::IntegrationTest
  fixtures :issues, :issue_statuses, :users,
    :projects, :roles, :members, :member_roles, :enabled_modules

  def setup
    default_plugin_settings
  end

  def test_create_only_if_authorized_and_has_permissions
    issue = issues(:issue_01)
    roles = users(:alice).members.find_by(project: issue.project_id).roles

    # cannot create without logging in
    assert_no_difference 'TokenVote.count' do
      post "#{issue_token_votes_path(issue)}.js", params: {
        token_vote: { token: 'BTCREG', duration: 1.day }
      }
    end
    assert_response :unauthorized

    # cannot create without permissions
    roles.each { |role| role.remove_permission! :manage_token_votes }
    log_user 'alice', 'foo'
    assert_no_difference 'TokenVote.count' do
      post "#{issue_token_votes_path(issue)}.js", params: {
        token_vote: { token: 'BTCREG', duration: 1.day }
      }
    end
    assert_response :forbidden
    roles.first.add_permission! :manage_token_votes

    # can create
    assert_difference 'TokenVote.count', 1 do
      post "#{issue_token_votes_path(issue)}.js", params: {
        token_vote: { token: 'BTCREG', duration: 1.day }
      }
      assert_nil flash[:error]
    end
    assert_response :ok
  end

  def test_destroy_only_if_authorized_and_deletable
    issue = issues(:issue_01)

    # create tv for destruction
    log_user 'alice', 'foo'
    assert_difference 'TokenVote.count', 1 do
      post "#{issue_token_votes_path(issue)}.js", params: {
        token_vote: { token: 'BTCREG', duration: 1.day }
      }
      assert_nil flash[:error]
    end
    assert_response :ok
    logout_user

    tv = TokenVote.first

    # cannot destroy without logging in
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(tv)}.js"
    end
    assert_response :unauthorized

    # cannot destroy if not owner
    log_user 'bob', 'foo'
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(tv)}.js"
    end
    assert_response :forbidden
    logout_user

    # cannot destroy without permissions
    log_user 'alice', 'foo'
    roles = users(:alice).members.find_by(project: issue.project_id).roles
    roles.each { |role| role.remove_permission! :manage_token_votes }
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(tv)}.js"
    end
    assert_response :forbidden
    roles.first.add_permission! :manage_token_votes

    # TODO: test for destruction without issue visibility

    # cannot destroy if founded
    tv.amount_unconf = 0.01
    tv.save!
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(tv)}.js"
    end
    assert_response :forbidden

    tv.amount_unconf = 0.0
    tv.amount_conf = 0.01
    tv.save!
    assert_no_difference 'TokenVote.count' do
      delete "#{token_vote_path(tv)}.js"
    end
    assert_response :forbidden
    tv.amount_conf = 0.0
    tv.save!

    # can destroy
    assert_difference 'TokenVote.count', -1 do
      delete "#{token_vote_path(tv)}.js"
    end
    assert_response :ok
  end
end

