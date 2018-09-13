class TokenWithdrawalController < ApplicationController
  before_filter :find_token_withdrawal, only: [:destroy]
  before_filter :authorize_global

  def create
    @token_withdrawal = TokenWithdrawal.new(token_withdrawal_params)
    @token_withdrawal.payee = User.current
    @token_withdrawal.save!
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    flash[:error] = e.message
  ensure
    @token_withdrawals = User.current.reload.token_withdrawals
  end

  def destroy
    @token_type.destroy
    @token_withdrawals = User.current.reload.token_withdrawals
  end

  def payout
    TokenWithdrawal.process_requested
  rescue RPC::Error => e
    flash[:error] = e.message
  ensure
    @token_withdrawals = TokenWithdrawal.all.reload.pending
  end

  private

  def token_withdrawal_params
    params.require(:token_withdrawal).permit(:token_type_id, :amount, :address)
  end

  def find_token_withdrawal
    @token_withdrawal = TokenWithdrawal.find(params[:id])
    raise Unauthorized unless @token_withdrawal.deletable?
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end

