require 'octokit'

require_relative './blockable'

class FissionError < StandardError
end

class Atomic
  include Blockable
  
  def initialize
    @cache = {}
  end

  def branches(repository)
   self.get_branches(repository)
  end
  
  def compare_branches(repository)
    # compare the branches on the fork against those on the source, by name and then by hash
    source_branches = Hash[self.get_branches(self.source_repo(repository)).collect {|x| [x[:name], x]}]
    fork_branches = Hash[self.get_branches(repository).collect {|x| [x[:name], x]}]
    # list of branches in the fork, but not in the source
    fork_only_branches = fork_branches.keys - source_branches.keys
    # local only branches
    differences = fork_branches.values.select {|x| fork_only_branches.include?(x[:name])}
    # iterate through the matching branches, comparing by SHA
    source_branches.each do |name, reference|
      if fork_branches.has_key?(name)
        if fork_branches[name][:commit][:sha] != reference[:commit][:sha]
          differences << fork_branches[name]
        end
      end
    end
    differences
  end
  
  def compare_commits(repository, branch)
    # compare the commits on the fork against those on the source for a branch using the sha
    source_commits = Hash[self.get_commits(self.source_repo(repository), branch).collect {|x| [x[:sha], x]}]
    fork_commits = Hash[self.get_commits(repository, branch).collect {|x| [x[:sha], x]}]
    fork_only_commits = fork_commits.keys - source_commits.keys
    fork_commits.values.select {|x| fork_only_commits.include?(x[:sha])}
  end
  
end