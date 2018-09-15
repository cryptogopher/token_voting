class TokenWithdrawalsController < ApplicationController
  before_filter :find_token_withdrawal, only: [:destroy]
  before_filter :authorize_global

  helper :issues

  def create
    @token_withdrawal = TokenWithdrawal.new(token_withdrawal_params)
    @token_withdrawal.payee = User.current
    @token_withdrawal.save!
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    flash[:error] = e.message
  else
    flash[:notice] = "Withdrawal request has been created"
  ensure
    @my_withdrawals = User.current.reload.token_withdrawals
  end

  def destroy
    if @token_withdrawal.destroy
      flash[:notice] = "Withdrawal request has been deleted"
    end
    @my_withdrawals = User.current.reload.token_withdrawals
  end

  def payout
    TokenWithdrawal.process_requested
  rescue RPC::Error => e
    flash[:error] = e.message
  else
    flash[:notice] = "Requested withdrawals have been processed succesfully"
  ensure
    @transactions = TokenTransaction.all.reload
    redirect_to my_token_votes_path(params: {tab: 'transactions'})
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

