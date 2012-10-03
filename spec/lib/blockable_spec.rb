require 'spec_helper'
require 'blockable'

class DummyClass
  include Blockable
end

describe Blockable do
  
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
    @fork_repo = {:clone_url => "https://github.com/someUser/Trance.git", 
                    :description => "Source code for Trance 5.6.4 - click below for more details", 
                    :fork => true, 
                    :full_name => "someUser/Trance", 
                    :organization => {
                      :id => 171103, 
                      :login => "someUser", 
                      :url => "https://api.github.com/users/someUser"}, 
                    :owner => {
                      :id => 171103,
                      :login => "someUser", 
                      :url => "https://api.github.com/users/someUser"}, 
                    :private => true, 
                    :pushed_at => "2012-09-17T13:17:14Z", 
                    :size => 6808,
                    :parent => {:full_name => "aUser/Trance"} }
    @source_repo = {:clone_url => "https://github.com/aUser/Trance.git", 
                    :description => "Source code for Trance 5.6.4 - click below for more details", 
                    :fork => false, 
                    :forks => 39, 
                    :forks_count => 39, 
                    :full_name => "aUser/Trance", 
                    :organization => {
                      :id => 171103, 
                      :login => "someUser", 
                      :url => "https://api.github.com/users/aUser"}, 
                    :owner => {
                      :id => 171103,
                      :login => "someUser", 
                      :url => "https://api.github.com/users/aUser"}, 
                    :private => true, 
                    :pushed_at => "2012-09-17T13:17:14Z", 
                    :size => 6808 }
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
  
  describe ".is_fork?" do
    
    it "identifies a fork repository" do
      # mock Octokit::Client
      d = DummyClass.new()
      # stub out the loading of the yml file
      d.stub(:login).and_return(@user)
      d.stub(:token).and_return(@token)
      d.stub(:get_repository).with("someUser/Trance").and_return(@fork_repo)
      d.is_fork?("someUser/Trance").should be_true
    end
    
    it "identifies a non-fork repository" do
      d = DummyClass.new()
      # stub out the loading of the yml file
      d.stub(:login).and_return(@user)
      d.stub(:token).and_return(@token)
      d.stub(:get_repository).with("aUser/AppleTrance").and_return(@source_repo)
      d.is_fork?("aUser/AppleTrance").should be_false
    end
  
  end
    
  describe ".source_repo" do
    
    it "returns the source repository for the fork" do
      # mock Octokit::Client
      d = DummyClass.new()
      # stub out the loading of the yml file
      d.stub(:get_repository).with("aUser/Trance").and_return(@source_repo)
      d.stub(:get_repository).with("someUser/Trance").and_return(@fork_repo)
      d.source_repo("someUser/Trance").should == @source_repo
    end
    
    it "returns the source repository for the source repository" do
      d = DummyClass.new()
      # stub out the loading of the yml file
      d.stub(:get_repository).with("aUser/Trance").and_return(@source_repo)
      d.source_repo("aUser/Trance").should == @source_repo
    end
    
  end
      
end