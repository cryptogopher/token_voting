module TokenVoting
  class TokenVotesViewListener < Redmine::Hook::ViewListener
    render_on :view_issues_show_description_bottom, partial: 'issues/token_votes_hook'
    render_on :view_layouts_base_html_head, partial: 'layouts/base'
  end
end

