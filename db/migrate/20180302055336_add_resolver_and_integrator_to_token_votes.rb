class AddResolverAndIntegratorToTokenVotes < ActiveRecord::Migration
  def change
    add_reference :token_votes, :resolver
    add_reference :token_votes, :integrator
  end
end
