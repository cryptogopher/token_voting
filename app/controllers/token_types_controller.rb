class TokenTypesController < ApplicationController

  before_action :require_admin

  def new
    @token_type = TokenType.new
  end

  def create
    @token_type = TokenType.new(token_type_params)
    respond_to do |format|
      format.html {
        if @token_type.save
          flash[:notice] = "Successfully created token type <b>#{@token_type.name}</b>"
          redirect_to plugin_settings_path('token_voting')
        else
          render :action => 'new'
        end
      }
    end
  end

  def destroy
    @token_type = TokenType.find(params[:id])
    raise Unauthorized unless @token_type.deletable?
    name = @token_type.name
    @token_type.destroy

    respond_to do |format|
      format.html {
        flash[:notice] = "Successfully deleted token type <b>#{name}</b>"
        redirect_to plugin_settings_path('token_voting')
      }
    end
  end

  private

  def token_type_params
    params.require(:token_type).permit(:name, :rpc_uri, :min_conf, :precision, :is_default)
  end
end

