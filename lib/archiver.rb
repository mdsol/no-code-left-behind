require 'grit'
require 'octokit'
require_relative './github_agent'

class ArchivingError < StandardError

end

class Archiver
  
  include GitHubAgent
  include Grit

  attr_reader :fork_name, :timeout, :options

  def initialize(options={})
    @fork_name = options[:repository]
    @timeout = options[:timeout]
    @options = options
  end

  def archive
    if validates?
      if needs_archiving?
        branches_to_archive.each do |branch_sha|
          copy_branch(branch_sha)
        end
      end
    end
  end

  def fork_repository
    unless defined?(@fork_repository)
      @fork_repository = client.repo(fork_name)
    end
    @fork_repository
  end

  def parent_repository
    # return the parent name
    unless defined?(@parent_repository)
      @parent_repository = client.repo(fork_repository.parent.full_name)
    end
    @parent_repository
  end

  def archive_repository
    # return the archive repository
    unless defined?(@archive_repository)
      # check the list of repos
      repository_ref = client.repositories.select {|x| x.name == fork_repository.name}.first
      if repository_ref.nil?
        client.fork(fork_repository.parent.full_name)
        repository_ref = client.repositories.select {|x| x.name == fork_repository.name}.first
      end
      @archive_repository = client.repo(repository_ref.full_name)
    end
    @archive_repository
  end

  def archive_branch_name(branch_name)
    # return archive_branch_name
    if has_similar_branches?
      branches = client.branches(fork_repository.full_name)
      if branches.collect {|x| x.name.downcase}.count(branch_name.downcase) != 1
        # a similar branch
        # get the similar branches
        brothers = branches.select {|x| x.name.downcase == branch_name.downcase}
                            .sort {|x,y| x.name <=> y.name}
                            .collect {|x| x.name}
        # add the index in the sorted subset
        [fork_repository.owner.login, branch_name, brothers.index(branch_name).to_s].join('_')
      else
        [fork_repository.owner.login, branch_name].join('_')
      end
    else
      [fork_repository.owner.login, branch_name].join('_')
    end
  end

  def needs_archiving?
    # does this repo need archiving? (are all the SHAs on the fork on the archive)
    not branches_to_archive.empty?
  end

  def branches_to_archive
    (repo_shas(fork_repository.full_name) - repo_shas(archive_repository.full_name))
  end

  def branch_name_exists?(branch_name)
    # does the branch name exist?
    client.branches(archive_repository.full_name).collect {|x| x.name }.include?(branch_name)
  end

  def has_similar_branches?
    branches = client.branches(fork_repository.full_name).collect {|x| x.name.downcase}
    # if the uniqued values are not the same as the un-uniqued
    branches != branches.uniq
  end

  def validates?
    # does the request make sense
    begin
      client.repo(fork_name).fork
    rescue Octokit::NotFound
      raise ArchivingError, "No such repository #{fork_name}"
    end
  end

  def clone
    # clones the archive repository
    unless defined? @clone
      tmpdir = Dir.mktmpdir
      # clone the archive repository
      begin
        git = Grit::Git.new(tmpdir)
        git.clone({quiet: false,
                   verbose: true,
                   progress: true,
                   timeout: timeout},
                  archive_repository.rels[:ssh].href,
                  File.join(tmpdir, archive_repository.name))
      rescue Git::GitTimeout
        raise ArchivingError, "Timeout #{timeout} exceeded on clone, increase and rerun"
      end
      @clone = Grit::Repo.new(File.join(tmpdir, archive_repository.name))
      # add a remote for the fork_owner
      @clone.remote_add(fork_repository.owner.login, fork_repository.rels[:ssh].href)
      # add a remote for the departed_user
      #@clone.remote_add(client.user.login, archive_repository.rels[:ssh].href)# add the fork as a remote
      begin
        @clone.git.fetch({:timeout => timeout}, fork_repository.owner.login)
      rescue Git::GitTimeout
        raise ArchivingError, "Timeout #{@timeout} exceeded on fetch, increase and rerun"
      end
    end
    @clone
  end

  def copy_branch(branch_sha)
    archive_branches = client.branches(archive_repository.full_name)
    unless archive_branches.collect {|x| x.commit.sha}.include?(branch_sha)
      fork_branches = client.branches(fork_repository.full_name)
      target_branch = fork_branches.select {|x| x.commit.sha == branch_sha}.first
      archive_branch_name = archive_branch_name(target_branch.name)
      # create the branch
      clone.git.branch({}, "#{archive_branch_name}", branch_sha)
      # push the branch to the remote
      begin
        clone.git.push({timeout: timeout},
                       'origin',
                       "#{archive_branch_name}:#{archive_branch_name}")
      rescue Git::TimeoutError
        raise ArchivingError, "Timeout #{@timeout} exceeded pushing branch #{archive_branch_name}"
      end
    end
  end

end