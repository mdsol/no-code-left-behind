require 'spec_helper'
require 'nuclear'
require 'grit'

describe KitchenDrawer do
  
  before :each do
    @user = "depUser"
    @token = Digest::SHA1.hexdigest "sometoken"
    @options = {:login => @user,
                :oauth_token => @token,
                :per_page => 100,
                :auto_traversal => true,
              }
    @source_repo = {:clone_url => "https://github.com/aUser/Trance.git", 
                    :description => "Source code for Trance 5.6.4 - click below for more details", 
                    :name => "Trance",
                    :fork => false, 
                    :forks => 39, 
                    :forks_count => 39, 
                    :full_name => "aUser/Trance", 
                    :organization => {
                      :id => 171123, 
                      :login => "aUser", 
                      :url => "https://api.github.com/users/aUser"}, 
                    :owner => {
                      :id => 171103,
                      :login => "aUser", 
                      :url => "https://api.github.com/users/aUser"}, 
                    :private => true, 
                    :pushed_at => time_rand, 
                    :size => 6808 }
    @fork_repo = {:clone_url => "https://github.com/someUser/Trance.git", 
                    :description => "Source code for Trance 5.6.4 - click below for more details", 
                    :name => "Trance",
                    :fork => true, 
                    :full_name => "someUser/Trance", 
                    :organization => {
                      :id => 171123, 
                      :login => "aUser", 
                      :url => "https://api.github.com/users/aUser"}, 
                    :owner => {
                      :id => 171113,
                      :login => "someUser", 
                      :url => "https://api.github.com/users/someUser"}, 
                    :private => true, 
                    :pushed_at => time_rand, 
                    :size => 6808,
                    :parent => {:full_name => "aUser/Trance"}}
    @dep_repo = {:clone_url => "https://github.com/depUser/Trance.git", 
                    :description => "Source code for Trance 5.6.4 - click below for more details", 
                    :name => "Trance",
                    :fork => true, 
                    :full_name => "depUser/Trance", 
                    :organization => {
                      :id => 171123, 
                      :login => "aUser", 
                      :url => "https://api.github.com/users/aUser"}, 
                    :owner => {
                      :id => 171103,
                      :login => "depUser", 
                      :url => "https://api.github.com/users/depUser"}, 
                    :private => true, 
                    :pushed_at => time_rand, 
                    :size => 6808,
                    :parent => {:full_name => "aUser/Trance"}}
    @d = KitchenDrawer.new
    @d.stub(:login).and_return(@user)
    @d.stub(:token).and_return(@token)
    @m = mock(Octokit::Client)
    @d.stub(:client).and_return(@m)
  end
  
  describe ".complete_merge?" do
    
    it "shows that all merges have been completed" do
      @m.stub(:login).and_return(@user)
      @m.stub!(:repository).with("someUser/Trance").and_return(@fork_repo)
      @m.stub!(:repository).with("depUser/Trance").and_return(@dep_repo)
      @m.stub!(:branches).with("depUser/Trance").and_return([{:name => "master"}, 
                                                            {:name => "develop"}, 
                                                            {:name => "someUser_develop"},   
                                                            {:name => "someUser_master"}])
      @m.stub!(:branches).with("someUser/Trance").and_return([{:name => "master"}, 
                                                              {:name => "develop"}, 
                                                              ])
      @d.complete_merge?("someUser/Trance").should be_true
    end
    
    it "shows that only a partial merge has taken place" do
      @m.stub(:login).and_return(@user)
      @m.stub!(:repository).with("someUser/Trance").and_return(@fork_repo)
      @m.stub!(:repository).with("depUser/Trance").and_return(@dep_repo)
      @m.stub!(:branches).with("depUser/Trance").and_return([{:name => "master"}, 
                                                            {:name => "develop"}, 
                                                            {:name => "someUser_develop"},   
                                                            {:name => "someUser_master"}])
      @m.stub!(:branches).with("someUser/Trance").and_return([{:name => "master"}, 
                                                              {:name => "develop"},
                                                              {:name => "feature/bells_and_whistles"} 
                                                              ])
      @d.complete_merge?("someUser/Trance").should be_false
    end
    
  end
  
  describe ".get_or_create_fork" do
    # Create a fork of the source repository
    it "returns the nominated fork when it already exists" do
      @m.stub!(:repositories).and_return([{:name => "Trance"}])
      @m.stub!(:repository).with("aUser/Trance").and_return(@source_repo)
      @m.stub!(:repository).with("someUser/Trance").and_return(@fork_repo)
      @m.stub!(:repository).with("depUser/Trance").and_return(@dep_repo)
      @m.stub(:login).and_return(@user)
      @d.get_or_create_fork("someUser/Trance").should == @dep_repo
    end

    it "creates the nominated fork when it doesn't already exists and return it" do
      # return no forks
      @m.stub(:repositories).and_return([])
      @m.should_receive(:fork).with("aUser/Trance")
      @m.stub(:repositories).and_return([{:full_name => "depUser/Trance"}])
      @m.stub(:repository).with("aUser/Trance").and_return(@source_repo)
      @m.stub(:repository).with("someUser/Trance").and_return(@fork_repo)
      @m.stub(:repository).with("depUser/Trance").and_return(@dep_repo)
      @m.stub(:login).and_return(@user)
      @d.get_or_create_fork("someUser/Trance").should == @dep_repo
    end
  end

  # describe ".archive_branch" do
  #   it "should archive the branch" do
  #     branch = mock(Grit::Remote)
  #     git = mock(Grit::Git)
  #     repo.stub!(:git).and_return(git)
  #     git.should_receive(:branch).with({}, "someUser_develop", "someUser/develop")
  #     git.should_receive(:push).with({}, "depUser", "someUser_develop")
  #     @m.stub(:login).and_return(@user)
  #     @m.archive_branch("", "")
  #   end
  # end
  
  describe ".clone_repository" do
    it "creates a local clone copy of a remote repository" do
      tmp_dir = @d.instance_variable_get("@tmplocation")
      @d.clone_repository({:full_name => "glow-mdsol/SHAREutils",
                            :name => "SHAREutils", 
                            :ssh_url => "git@github.com:glow-mdsol/SHAREutils.git"})
      File.exist?(File.join(tmp_dir, "SHAREutils", ".git")).should be_true
    end
  end
  
  describe ".merge_fork" do
    it "clones the fork" do
      pending("Massive function difficult to refactor")
    end
  end
   
end