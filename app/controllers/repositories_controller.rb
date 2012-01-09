class RepositoriesController < ApplicationController
  load_and_authorize_resource except: [:sync, :sync_proxy]
  before_filter :authenticate_user!, except: [:show, :sync, :sync_proxy]
  before_filter :load_repository, only: [:show, :edit, :update]
  before_filter :check_allow_repositories_count, only: [:new, :create]
  respond_to :json, :html

  def index
    if current_user.sync_repos?
      respond_with(current_user.repositories)
    else
      respond_with(error: "not_ready")
    end
  end

  def show
    set_current_repository(@repository)
  end

  def new
    if check_allow_repositories_count
      @repository = Repository.new
    end
  end

  def create
    if check_allow_repositories_count
      @repository = current_user.add_repository(params[:repository][:github_name])
      if @repository.valid?
        redirect_to [:edit, @repository], notice: "Repository created successfully."
      else
        render :new
      end
    end
  rescue Octokit::NotFound
    flash[:error] = "There is no such repository or you don't have access to such repository on githbub"
    redirect_to action: :new
  rescue AuthorizationException => e
    flash[:error] = e.message
    redirect_to [:new, :repository]
  end

  def edit
  end

  def update
    if @repository.update_attributes(params[:repository])
      redirect_to [:edit, @repository], notice: "Repository updated successfully."
    else
      @configs = RepositoryConfigs.new(@repository).read
      render :edit
    end
  end

  def sync
    render text: "not authenticate" and return if params[:token].blank?

    payload = ActiveSupport::JSON.decode(params[:payload])
    repository = Repository.where(html_url: payload["repository"]["url"]).first
    render text: "not authenticate" and return unless repository
    render text: "not authenticate" and return unless repository.authentication_token == params["token"]

    if payload["ref"] =~ /#{repository.branch}$/
      repository.generate_build(payload["commits"].last)
      render text: "success"
    else
      render text: "skip"
    end
  end

  def sync_proxy
    render text: "not authenticate" and return if params[:token].blank?

    repository = Repository.where(html_url: params[:repository_url]).first
    render text: "not authenticate" and return unless repository
    render text: "not authenticate" and return unless repository.authentication_token == params[:token]

    if params[:error].present?
      raise Marshal.load(params[:error])
    elsif params[:ref] =~ /#{repository.branch}$/
      errors = ActiveSupport::JSON.decode(params[:result])["errors"]
      repository.generate_proxy_build(params[:last_commit], errors)
      render text: "success"
    else
      render text: "skip"
    end
  end

  protected
    def load_repository
      @repository = Repository.find(params[:id])
    end

    def check_allow_repositories_count
      if current_user.allow_repositories_count <= current_user.own_repositories_count
        flash[:error] = "You are not authorized to create a new repository, please upgrade your plan."
        redirect_to root_url
        return false
      end
      true
    end
end
