class TokenVotesListener < Redmine::Hook::Listener
  def controller_issues_edit_after_save(event)
    TokenVote.issue_edit_hook(event[:issue])
  end
end
