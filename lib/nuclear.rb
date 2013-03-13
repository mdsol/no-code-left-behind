require 'octokit'
require 'grit'
require_relative './blockable'

=begin
[REMOTE]Need to use the github api to create the fork
[LOCAL]Need to use the git api to clone the fork
[LOCAL]Need to use the git api to add the remote
[LOCAL]Need to use the git api to create the branch
[LOCAL]Need to use the git api to push the new branch to the remote
TODO: Handle case where branch is created, but not registered as being (probably time related)
TODO: Git Timeout seems a bit idiopathic - need to dig into GRIT to see where it's coming from
=end

class FissionError < StandardError
end

class KitchenDrawer
  include Blockable
  include Grit
  
  def initialize(timeout=240)
    @tmplocation = Dir.mktmpdir
    @timeout = timeout
    # kick back if not a fork
  end

  def is_merged?(forked_repository, parent_repo="")
    # return true if the forked_branches are already on the departedusers fork
    owner = get_repository(forked_repository)[:owner][:login]
    name = get_repository(forked_repository)[:name]
    if parent_repo.eql?("")
      # derive from repository
      parent = get_repository(forked_repository)[:parent]
    else 
      # parent specified - use this
      parent = { :name => parent_repo.split('/').last }
    end
    fork_branches = get_branches(forked_repository).collect {|x| "#{owner}_#{x[:name]}"}
    begin
      dep_repo_branches = get_branches("#{client.login}/#{parent[:name]}").select {|x| x[:name].start_with?("#{owner}_")}.collect {|x| x[:name]}
      fork_branches.sort == dep_repo_branches.sort
    rescue Octokit::NotFound
      return false
    end
    
  end
  
  def merge_fork(forked_repository, parent_repo="")
    # intended to be called multiple times
    # name of forked repo
    if is_fork?(forked_repository)
      status = false
      if is_merged?(forked_repository, parent_repo)
        status = true
      else
        get_or_create_fork(forked_repository, parent_repo)
        merge_forked_repository(forked_repository, parent_repo)
        status = is_merged?(forked_repository, parent_repo)
        # remove it from the cache
        expire(forked_repository)
        # return whether it was a complete merge
      end
      # to generate the URLs for deletion
      status
    else
      raise FissionError, "#{forked_repository} is not a fork"
    end
  end
    
  def get_or_create_fork(repository_name, parent_repo="")
    # create a fork for the source repository (as the departeduser) [using GH api]
    # check and see if the fork already exists in the departedusers list (as we are 
    #  logging in using this account)
    if parent_repo == ""
      # take the parent
      source_repo = source_repo(repository_name) 
    else
      # specify the parent
      source_repo = client.repository(parent_repo)
    end
    my_repos = client.repositories().collect {|x| x[:name]}
    unless my_repos.include?(source_repo[:name])
      puts "Forking #{source_repo[:full_name]}"
      client.fork(source_repo[:full_name])
    end
    # return repository object
    # this is tacky.... 
    client.repository("#{self.client.login}/#{source_repo[:name]}")
  end
  
  def merge_forked_repository(fork_repository, parent_repo="")
    # TODO: refactor this - massive function, but the grit deps are a pain
    
    # retrieve the repo hashes
    if parent_repo.eql?("")
      source_repo = source_repo(fork_repository)
    else
      source_repo = get_repository(parent_repo)
    end
    fork_repo = get_repository(fork_repository)
    dep_repo = my_fork(source_repo[:name])
    
    # synonyms for clarity
    fork_owner = fork_repo[:owner][:login]
    departed_user = client.login
    
    # if the clone already exists, then reuse it, otherwise clone (can take a long time)
    unless Dir.exist?(File.join(@tmplocation, source_repo[:name]))
      clone_repository(source_repo)
    end
    
    # Repo object
    g = Grit::Repo.new(File.join(@tmplocation, source_repo[:name]))
    
    # add a remote for the fork_owner
    g.remote_add(fork_owner, fork_repo[:ssh_url])
    # add a remote for the departed_user
    g.remote_add(departed_user, dep_repo[:ssh_url])
    
    # fetch the forked repo
    # TODO: where does the timeout variable come from
    # TODO: when a timeout occurs roll-back the git action
    begin
      g.git.fetch({:timeout => @timeout}, fork_owner)
    rescue Git::GitTimeout
      raise FissionError, "Timeout #{@timeout} exceeded on fetch, increase and rerun"
    end  
    remote_branches = self.client.branches(dep_repo[:full_name]).collect {|x| x[:name]}
    # iterate through the branches on the local 
    g.remotes.select {|x| x.name.start_with?(fork_owner)}.each do |branch|
      puts "Cloning #{branch.name}"
      cloned_branch = branch.name.gsub("#{fork_owner}/", "#{fork_owner}_")
      # using GH api here
      # only create and push if the branch doesn't already exist
      unless remote_branches.include?(cloned_branch)
        owner = branch.name.split('/').first
        cloned_branch = branch.name.gsub("#{owner}/", "#{owner}_")
        # create the branch as "{leaver}_{branch_name}"
        # create the branch on the local copy
        g.git.branch({}, cloned_branch, branch.name)
        # push the branch to the departed user fork
        begin
          g.git.push({:timeout => @timeout}, self.client.login, "#{cloned_branch}:#{cloned_branch}")
        rescue Git::GitTimeout
          raise FissionError,"Timeout #{@timeout} exceeded on push, increase and rerun"
        end 
      end
    end
    # clear the cache
    clear_cache 
  end
  
  def archive_branch(path, branch)
    # path - path to the checked out repo
    # branch - the Grit::Remote remote 
    # cloned branch {leaver}_{branch}, eg someUser_develop, someUser_feature/sausages
    # branch.full is like remotes/someUser/
    owner = branch.name.split('/').first
    cloned_branch = branch.name.gsub("#{owner}/", "#{owner}_")
    # create the branch as "{leaver}_{branch_name}"
    # create the branch on the local copy
    g = Grit::Repo.new(path)
    g.git.branch({}, cloned_branch, branch.name)
    # push the branch to the departed user fork
    begin
      g.git.push({:timeout => @timeout}, self.client.login, "#{cloned_branch}:#{cloned_branch}")
    rescue Git::GitTimeout
      raise FissionError,"Timeout #{@timeout} exceeded on push, increase and rerun"
    end 
  end
  
  def clone_repository(repository)
    # clone repository to local system
    begin
      puts "Creating local clone of source #{repository[:full_name]}"
      # need to clone the directory
      gitty = Grit::Git.new(@tmplocation)
      # clone of some projects can take a while, I'm thinking of you R...
      # timeout is in seconds - allow 40m to clone
      gitty.clone({:quiet => false, 
                  :verbose => true, 
                  :progress => true,
                  :timeout => @timeout}, 
                  repository[:ssh_url], 
                  File.join(@tmplocation, repository[:name]))
    rescue Git::Timeout
      raise FissionError, "Timeout #{@timeout} exceeded on clone, increase and rerun"
    end
  end
end