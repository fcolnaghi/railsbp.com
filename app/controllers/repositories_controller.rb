class RepositoriesController < ApplicationController
  before_filter :authenticate_user!, :except => :sync
  before_filter :set_current_user, :only => :create
  respond_to :json, :html

  def index
    if current_user.sync_repos?
      respond_with(current_user.repositories)
    else
      respond_with(error: "not_ready")
    end
  end

  def show
    @repository = Repository.find(params[:id])
  end

  def new
    @repository = Repository.new
  end

  def create
    @repository = current_user.repositories.build(params[:repository])
    if @repository.save
      redirect_to repository_path(@repository)
    else
      render :action => :new
    end
  end

  def sync
    payload = ActiveSupport::JSON.decode(params[:payload])
    repository = Repository.where(:html_url => payload["repository"]["url"]).first
    repository.generate_build(payload["commits"].first["id"])
    render :text => 'success'
  end
end
