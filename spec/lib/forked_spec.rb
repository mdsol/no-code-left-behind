require 'spec_helper'

require 'forked'
# require 'atomic'

describe ForkedReport do

  before :each do
    # changes for fork
    @branch_delta = [{:commit => {:sha => "6f786ba21fc1bc1cd23851a60021ff24a6b8ba64"}, :name => "feature/some_new_config"}, 
                    {:commit => {:sha => "6f786ba21fc1bc1cd23851a60021ff24a6b8ba64"}, :name => "feature/where_am_i"},
                    {:commit => {:sha => "6f786ba21fc1bc1cd23851a60021ff24a6b8ba64"}, :name => "develop"},]
    @source_repo = {:clone_url => "https://github.com/mdsoul/SomeRepo.git", 
                    :description => "Source code for Trance 5.6.4 - click below for more details", 
                    :fork => false, 
                    :forks => 39, 
                    :forks_count => 39, 
                    :full_name => "mdsoul/SomeRepo", 
                    :organization => {
                      :id => 171103, 
                      :login => "mdsoul", 
                      :url => "https://api.github.com/users/mdsoul"}, 
                    :owner => {
                      :id => 171103,
                      :login => "mdsoul", 
                      :url => "https://api.github.com/users/mdsoul"}, 
                    :private => true, 
                    :pushed_at => "2012-09-17T13:17:14Z", 
                    :size => 6808 }
    @diff_commit = generate_commit
    # @atomic = mock(Atomic)
    # @atomic.stub!(:source_repo).with("forker/SomeFork").and_return(@source_repo)
    # @atomic.stub!(:compare_branches).with("forker/SomeFork").and_return(@branch_delta)
    # @atomic.stub!(:compare_commits).with("forker/SomeFork", "develop").and_return(@diff_commit)
  end
  
  describe ".add_local_branches" do
    it "should add a local branch" do
      forked = ForkedReport.new("forker/SomeRepo", "mdsoul/SomeRepo")
      forked.add_local_branches(@branch_delta)
      forked.local_branches.length.should == 3
      forked.local_branches.should =~ @branch_delta
    end
    
    it "should add an empty list when no local_branches" do
      forked = ForkedReport.new("forker/SomeRepo", "mdsoul/SomeRepo")
      forked.add_local_branches([])
      forked.local_branches.length.should == 0
      forked.local_branches.should == []
    end
  end
  
  describe ".add_local_commits" do
    it "should add a set of local commits" do
      forked = ForkedReport.new("forker/SomeRepo", "mdsoul/SomeRepo")
      commit = generate_commit
      forked.add_local_commits("develop", [@diff_commit])
      forked.local_commits.length.should == 1
      forked.local_commits["develop"].should == [@diff_commit]
    end

    it "should add a set of local commits for muliple branches" do
      forked = ForkedReport.new("forker/SomeRepo", "mdsoul/SomeRepo")
      develop_commit = generate_commit
      forked.add_local_commits("develop", [develop_commit])
      master_commit = generate_commit
      forked.add_local_commits("master", [master_commit])
      forked.local_commits.length.should == 2
    end
    
    it "should add an empty list when no local_commits" do
      forked = ForkedReport.new("forker/SomeRepo", "mdsoul/SomeRepo")
      forked.add_local_commits("develop", [])
      forked.local_commits.length.should == 0
      forked.local_commits.should == {}
    end
    
  end
  
  describe ".all_issues" do
    it "should report the number of issues found" do
      forked = ForkedReport.new("forker/SomeRepo", "mdsoul/SomeRepo")
      develop_commit = generate_commit
      forked.add_local_commits("develop", [develop_commit])
      master_commit = generate_commit
      forked.add_local_commits("master", [master_commit])
      forked.add_local_branches(@branch_delta)
      forked.all_issues.length.should == 5 
    end
  end  
  
  describe ".as_stdout" do
    it "should support producing the report to stdout with branch differences" do
      forked = ForkedReport.new("forker/SomeRepo", "mdsoul/SomeRepo")
      forked.add_local_branches(@branch_delta)
      forked.as_stdout.should  =~ /develop \(6f786ba21fc1bc1cd23851a60021ff24a6b8ba64\)/m
      forked.as_stdout.should =~ /feature\/some_new_config \(6f786ba21fc1bc1cd23851a60021ff24a6b8ba64\)/m
      forked.as_stdout.should =~ /feature\/where_am_i \(6f786ba21fc1bc1cd23851a60021ff24a6b8ba64\)/m
    end
    it "should support producing the report to stdout with commit differences" do
      forked = ForkedReport.new("forker/SomeRepo", "mdsoul/SomeRepo")
      master_commit = generate_commit
      forked.add_local_commits("master", [master_commit])
      forked.as_stdout.should =~ /Branch: master\n - '#{master_commit[:commit][:message]}' \(#{master_commit[:sha]}\)/m
      
    end
  end  
  
  describe ".as_excel" do
    it "should support producing the report as a report to an excel document" do
      pending "Write the Excel Output Module"
    end
  end
    
end