class Build < ActiveRecord::Base
  include AASM

  belongs_to :repository

  after_create :analyze

  aasm do
    state :scheduled, initial: true
    state :running
    state :completed

    event :run do
      transitions to: :running, from: [:scheduled, :running]
    end

    event :complete do
      transitions to: :completed, from: :running
    end
  end

  def analyze_path
    Rails.root.join("builds", repository.github_name, "commit", last_commit_id).to_s
  end

  def analyze_file
    analyze_path + "/rbp.html"
  end

  def analyze
    run!
    FileUtils.mkdir_p(analyze_path) unless File.exist?(analyze_path)
    FileUtils.cd(analyze_path)
    Git.clone(repository.clone_url, repository.name)
    rails_best_practices = RailsBestPractices::Analyzer.new(analyze_path,
                                                            "format"         => "html",
                                                            "silent"         => true,
                                                            "output-file"    => analyze_file,
                                                            "with-github"    => true,
                                                            "github-name"    => repository.github_name,
                                                            "last-commit-id" => last_commit_id,
                                                            "only-table"     => true
                                                           )
    rails_best_practices.analyze
    rails_best_practices.output
    FileUtils.rm_rf("#{analyze_path}/#{repository.name}")
    complete!
  end
  handle_asynchronously :analyze
end