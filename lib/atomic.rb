require 'octokit'

class Atomic

  def initialize(user, token)
    @client = Octokit::Client.new({:login => user, :oauth_token => token})
    @cache = {}
  end

  
  def compare_branches(repository)
    # compare the branches on the fork against those on the source
    source_branches = self.branches(self.source_repo(repository))
    fork_branches = self.branches(repository)
    fork_branches - source_branches
  end
  
  def compare_commits(repository, branch)
    # compare the commits on the fork against those on the source for a branch
    source_commits = self.commits(self.source_repo(repository), branch)
    fork_commits = self.commits(repository, branch)
    fork_commits - source_commits
  end
  
  protected

  def branches(repository)
    unless @cache.has_key?(repository)
      # cache the pull
      @cache[repository] = @client.branches(repository)  
    end
    @cache[repository]
  end

  def commits(repository, branch)
    unless @cache.has_key?("#{repository}_#{branch}")
      # cache this 
      @cache["#{repository}_#{branch}"] = @client.commits(repository, branch)
    end
    @cache["#{repository}_#{branch}"]
  end
  
  def source_repo(repository)
    repo = @client.repository(repository)
    if repo[:fork] == false
      # not a fork
      repo[:full_name]    
    else
      # a fork
      repo[:parent][:full_name]
    end

  end
  
end