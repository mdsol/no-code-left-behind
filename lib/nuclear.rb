require 'octokit'
require 'grit'
require_relative './blockable'

=begin
[REMOTE]Need to use the github api to create the fork
[LOCAL]Need to use the git api to clone the fork
[LOCAL]Need to use the git api to add the remote
[LOCAL]Need to use the git api to create the branch
[LOCAL]Need to use the git api to push the new branch to the remote
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

  def merge_fork(forked_repository)
    # intended to be called multiple times
    # name of forked repo
    if self.is_fork?(forked_repository)
      self.get_or_create_fork(forked_repository)
      self.merge_forked_repository(forked_repository)
      self.complete_merge?(forked_repository)
    else
      raise FissionError, "#{forked_repository} is not a fork"
    end
  end
  
  def complete_merge?(forked_repository)
    forked_repo = self.get_repository(forked_repository)
    owner = forked_repo[:owner][:login]
    dep_repo_branches = self.get_branches("#{self.client.login}/#{forked_repo[:name]}").collect {|x| x[:name] if x[:name].start_with?(owner)}
    fork_repo_branches = self.get_branches(forked_repository).collect {|x| x[:name]}
    complete_merge = true
    fork_repo_branches.each do |branch_name|
      unless dep_repo_branches.include?("#{owner}_#{branch_name}")
        p "Unsuccessful merge for #{forked_repository} branch #{branch_name}"
        complete_merge = false
      end
    end
    complete_merge
  end
  
  def get_or_create_fork(repository_name)
    # create a fork for the source repository (as the departeduser) [using GH api]
    # check and see if the fork already exists in the departedusers list (as we are 
    #  logging in using this account)
    source_repo = self.source_repo(repository_name)
    my_repos = self.client.repositories().collect {|x| x[:name]}
    unless my_repos.include?(source_repo[:name])
      puts "Forking #{source_repo[:full_name]}"
      self.client.fork(source_repo[:full_name])
    end
    # return repository object
    # this is tacky.... 
    self.client.repository("#{self.client.login}/#{source_repo[:name]}")
  end
  
  def merge_forked_repository(fork_repository)
    # TODO: refactor this - massive function, but the grit deps are a pain
    
    # retrieve the repo hashes
    source_repo = self.source_repo(fork_repository)
    fork_repo = self.get_repository(fork_repository)
    dep_repo = self.my_fork(source_repo[:name])
    
    # synonyms for clarity
    fork_owner = fork_repo[:owner][:login]
    departed_user = self.client.login
    
    # if the clone already exists, then reuse it, otherwise clone (can take a long time)
    unless Dir.exist?(File.join(@tmplocation, source_repo[:name]))
      self.clone_repository(source_repo)
    end
    
    # Repo object
    g = Grit::Repo.new(File.join(@tmplocation, source_repo[:name]))
    
    # add a remote for the fork_owner
    g.remote_add(fork_owner, fork_repo[:ssh_url])
    # add a remote for the departed_user
    g.remote_add(departed_user, dep_repo[:ssh_url])
    
    # fetch the forked repo
    begin
      g.git.fetch({:timeout => @timeout}, fork_owner)
    rescue Git::Timeout
      raise FissionError, "Timeout #{@timeout} exceeded on fetch, increase and rerun"
    end  
    remote_branches = self.client.branches(dep_repo[:full_name]).collect {|x| x[:name]}
    # iterate through the branches on the local 
    g.remotes.select {|x| x.name.start_with?(fork_owner)}.each do |branch|
      # cloned branch {leaver}_{branch}, eg someUser_develop, someUser_feature/sausages
      # branch.full is like remotes/someUser/
      cloned_branch = branch.name.gsub("#{fork_owner}/", "#{fork_owner}_")
      # using GH api here
      # only create and push if the branch doesn't already exist
      if remote_branches.include?(cloned_branch)
        puts "#{cloned_branch} already merged"
      else
        puts "Cloning #{branch.name} as #{cloned_branch}"
        # create the branch as "{leaver}_{branch_name}"
        # create the branch on the local copy
        g.git.branch({}, cloned_branch, branch.name)
        # push the branch to the departed user fork
        begin
          g.git.push({}, self.client.login, "#{cloned_branch}:#{cloned_branch}")
        rescue Git::Timeout
          raise FissionError,"Timeout #{@timeout} exceeded on fetch, increase and rerun"
        end 
      end
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