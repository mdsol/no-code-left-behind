require 'spec_helper'
require 'octokit'
require 'hashie'
require 'atomic'

describe Atomic do
  
  before :each do
    # these are both serialisations of a response from the client
    @source_branches  =  [
      {:commit => {:sha => "4be04eabf80589d6fc311901a6bec167d1cdf9d7"}, :name => "hotfix/v5.6.4-Patch2_build_53_with_fixes"}, 
      {:commit => {:sha => "d7e4b25f418e6f5cbcae74fcc8aec6c1a08aaca8"}, :name => "trance_integration"}, 
      {:commit => {:sha => "354c0a4043cd2f16ddbc62f205eb129e7823282f"}, :name => "feature/patch10_11Delta"}, 
      {:commit => {:sha => "fe0f0a210ea5fc288a5da7f3e693196ae6b22212"}, :name => "hotfix/v5.6.4-Patch1_build_52_with_fixes"}, 
      {:commit => {:sha => "8cef4109592cf4b6d0e56390643f9501507b601b"}, :name => "develop"}, 
      {:commit => {:sha => "1e52a892fedce8b4c7d7d4491c411ee104adae1f"}, :name => "master"}, 
      {:commit => {:sha => "ba14d901113a257fb09bc56474b23be32442648d"}, :name => "feature/MEF_SubModule"},
      ] 
    # copy the branches for 
    @fork_branches = @source_branches.dup
    # changes for fork
    @branch_delta = [{:commit => {:sha => "6f786ba21fc1bc1cd23851a60021ff24a6b8ba64"}, :name => "feature/some_new_config"}, 
                      {:commit => {:sha => "6f786ba21fc1bc1cd23851a60021ff24a6b8ba65"}, :name => "feature/where_am_i"}]
    @fork_branches.concat(@branch_delta)
    @fork_branches_upd  =  [
      {:commit => {:sha => "35f83be35aa24e83cf2a17b6644238c0db51a0c6"}, :name => "hotfix/v5.6.4-Patch2_build_53_with_fixes"}, 
      {:commit => {:sha => "d7e4b25f418e6f5cbcae74fcc8aec6c1a08aaca8"}, :name => "trance_integration"}, 
      {:commit => {:sha => "354c0a4043cd2f16ddbc62f205eb129e7823282f"}, :name => "feature/patch10_11Delta"}, 
      {:commit => {:sha => "fe0f0a210ea5fc288a5da7f3e693196ae6b22212"}, :name => "hotfix/v5.6.4-Patch1_build_52_with_fixes"}, 
      {:commit => {:sha => "8cef4109592cf4b6d0e56390643f9501507b601b"}, :name => "develop"}, 
      {:commit => {:sha => "1e52a892fedce8b4c7d7d4491c411ee104adae1f"}, :name => "master"}, 
      {:commit => {:sha => "ba14d901113a257fb09bc56474b23be32442648d"}, :name => "feature/MEF_SubModule"},
      
      ] 
    @source_repo = {:clone_url => "https://github.com/mdsoul/Trance.git", 
                    :description => "Source code for Trance 5.6.4 - click below for more details", 
                    :fork => false, 
                    :forks => 39, 
                    :forks_count => 39, 
                    :full_name => "mdsoul/Trance", 
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
    @fork_repo = @source_repo.dup
    @fork_repo[:fork] = true
    @fork_repo[:full_name] = "someUser/Trance"
    @fork_repo[:clone_url] = "https://github.com/someUser/Trance.git"
    @fork_repo[:parent] = {:full_name => "mdsoul/Trance"}
    
    @source_commits = [generate_commit, generate_commit, generate_commit]
    @diff_commit = generate_commit
    @fork_commits = @source_commits.dup << @diff_commit
    @user = "someuser"
    @token = Digest::SHA1.hexdigest "sometoken"
    @options = {:login => @user,
                :oauth_token => @token,
                :per_page => 100,
                :auto_traversal => true,
              }
  end
  
  
  describe ".compare_branches" do
    it "should generate a list of branches on the fork, but not the source" do
      m = mock(Octokit::Client)
      Octokit::Client.should_receive(:new).with(@options).and_return(m)
      m.stub!(:repository).with("someUser/Trance").and_return(@fork_repo)
      m.stub!(:branches).with("mdsoul/Trance").and_return(@source_branches)
      m.stub!(:branches).with("someUser/Trance").and_return(@fork_branches)
      a = Atomic.new
      a.compare_branches("someUser/Trance").should =~ @branch_delta
    end
    it "with no changes return empty array" do
      m = mock(Octokit::Client)
      Octokit::Client.should_receive(:new).with(@options).and_return(m)
      m.stub!(:repository).with("someUser/Trance").and_return(@fork_repo)
      m.stub!(:branches).with("mdsoul/Trance").and_return(@source_branches)
      m.stub!(:branches).with("someUser/Trance").and_return(@source_branches)
      a = Atomic.new
      a.compare_branches("someUser/Trance").should == []
    end
    it "should generate a list of branches that have changed on the fork, but not the source" do
      m = mock(Octokit::Client)
      Octokit::Client.should_receive(:new).with(@options).and_return(m)
      m.stub!(:repository).with("someUser/Trance").and_return(@fork_repo)
      m.stub!(:branches).with("mdsoul/Trance").and_return(@source_branches)
      m.stub!(:branches).with("someUser/Trance").and_return(@fork_branches_upd)
      a = Atomic.new
      a.compare_branches("someUser/Trance").should == [@fork_branches_upd[0]]
    end
    it "should generate a list of branches that have changed on the fork, both the source and new branches" do
      m = mock(Octokit::Client)
      Octokit::Client.should_receive(:new).with(@options).and_return(m)
      m.stub!(:repository).with("someUser/Trance").and_return(@fork_repo)
      m.stub!(:branches).with("mdsoul/Trance").and_return(@source_branches)
      local_branches = @fork_branches_upd.concat(@branch_delta)
      m.stub!(:branches).with("someUser/Trance").and_return(local_branches)
      a = Atomic.new
      a.compare_branches("someUser/Trance").should == @branch_delta + [@fork_branches_upd[0]]
    end
  end

  describe ".compare_commits" do
    it "should return an empty list for the case where the commits are the same" do
      m = mock(Octokit::Client)
      Octokit::Client.should_receive(:new).with(@options).and_return(m)
      m.stub!(:repository).with("someUser/Trance").and_return(@fork_repo)
      m.stub!(:commits).with("someUser/Trance", "develop").and_return(@source_commits)
      m.stub!(:commits).with("mdsoul/Trance", "develop").and_return(@source_commits)
      a = Atomic.new
      a.compare_commits("someUser/Trance", "develop").should == []
    end
    it "should return an list for the case where there are missing commits present in the fork" do
      m = mock(Octokit::Client)
      Octokit::Client.should_receive(:new).with(@options).and_return(m)
      m.stub!(:repository).with("someUser/Trance").and_return(@fork_repo)
      m.stub!(:commits).with("someUser/Trance", "develop").and_return(@fork_commits)
      m.stub!(:commits).with("mdsoul/Trance", "develop").and_return(@source_commits)
      a = Atomic.new
      a.compare_commits("someUser/Trance", "develop").should == [@diff_commit]
    end
    it "should return an empty list for the case where the source is ahead" do
      m = mock(Octokit::Client)
      Octokit::Client.should_receive(:new).with(@options).and_return(m)
      m.stub!(:repository).with("someUser/Trance").and_return(@fork_repo)
      m.stub!(:commits).with("someUser/Trance", "develop").and_return(@source_commits[0..-1])
      m.stub!(:commits).with("mdsoul/Trance", "develop").and_return(@source_commits)
      a = Atomic.new
      a.compare_commits("someUser/Trance", "develop").should == []
    end
  end
  


end