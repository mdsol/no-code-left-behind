require 'write_xlsx'
require 'yaml'

class ForkedReport 

  attr_reader :issues
  
  def initialize(repository, source_repository)
    @repository = repository
    @source_repository = source_repository
    @issues = {:local_branches => [], :local_commits => {}}
  end

  def all_issues
    issues ||= @issues[:local_branches] 
    @issues[:local_commits].each_value do |commits|
      issues += commits
    end
    issues
  end
  
  def local_branches
    @issues[:local_branches].sort {|x,y| x[:name] <=> y[:name]}
  end

  def local_commits
    @issues[:local_commits]
  end
  
  def add_local_branches(branches)
    unless branches.empty?
      @issues[:local_branches] = branches
    end
  end
  
  def add_local_commits(branch, commits)
    unless commits.empty?
      @issues[:local_commits][branch] = commits 
    end
  end
  
  def as_stdout
    report ||= "Fork Report\n"
    report += "Fork Repository: #{@repository}\n"
    report += "Source Repository: #{@source_repository}\n"
    unless self.local_branches.empty?
      report += "Branches present on #{@repository} but missing from #{@source_repository}\n"
      self.local_branches.each do |branch|
        report += "#{branch[:name]} (#{branch[:commit][:sha]})\n"
      end
    end
    unless self.local_commits.empty?
      report += "Commits present on #{@repository} but missing from #{@source_repository}\n"
      self.local_commits.each do |branch, commits|
        report += "Branch: #{branch}\n"
        commits.each do |single_commit|
          report += " - '#{single_commit[:commit][:message]}' (#{single_commit[:sha]})"
        end
      end
    end
    report
  end

  def as_yaml
    YAML::dump({'fork' => @repository, 'branches' => self.local_branches.collect {|x| x[:name]}})
  end
end