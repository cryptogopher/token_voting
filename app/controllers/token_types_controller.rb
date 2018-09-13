class TokenTypesController < ApplicationController
  layout 'admin'

  before_filter :find_token_type, only: [:edit, :update, :destroy]
  before_filter :require_admin

  def new
    @token_type = TokenType.new
  end

  def create
    @token_type = TokenType.new(token_type_params)
    if @token_type.save
      reset_defaults if @token_type.is_default
      flash[:notice] = "Successfully created token type <b>#{@token_type.name}</b>"
      redirect_to plugin_settings_path('token_voting')
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    if @token_type.update(token_type_params)
      reset_defaults if @token_type.is_default
      flash[:notice] = "Successfully updated token type <b>#{@token_type.name}</b>"
      redirect_to plugin_settings_path('token_voting')
    else
      render :action => 'edit'
    end
  end

  def destroy
    raise Unauthorized unless @token_type.deletable?
    name = @token_type.name

    if @token_type.destroy
      flash[:notice] = "Successfully deleted token type <b>#{name}</b>"
    else
      flash[:error] = "Cannot deleted token type <b>#{name}</b>"
    end
    redirect_to plugin_settings_path('token_voting')
  end

  private

  def reset_defaults
    TokenType.where(is_default: true).where.not(id: @token_type).update_all(is_default: false)
  end

  def token_type_params
    params.require(:token_type).permit(:name, :rpc_uri, :min_conf, :is_default)
  end

  def find_token_type
    @token_type = TokenType.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end

