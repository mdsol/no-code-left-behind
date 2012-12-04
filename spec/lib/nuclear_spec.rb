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
  
  describe ".is_merged?" do
    
    it "returns true if all branches are merged" do
      @m.stub(:login).and_return(@user)
      # need to get the owner and forkname
      @d.stub(:get_repository).with("someOwner/someFork").and_return({:name => "someFork", 
        :owner => {:login => "someOwner"},
        :parent => {:name => "someFork"}})
      # get the branches from the fork
      @d.stub(:get_branches).with("someOwner/someFork").and_return([{:name => "master"}, {:name => "develop"}])
      # return the list of branches on the departed user fork
      @d.stub(:get_branches).with("#{@user}/someFork").and_return([{:name => "someOwner_master"}, {:name => "someOwner_develop"}])
      @d.is_merged?("someOwner/someFork").should be_true
    end
    
    it "returns false if all branches are not merged" do
      @m.stub(:login).and_return(@user)
      @d.stub(:get_repository).with("someOwner/someFork").and_return({:name => "someFork", 
        :owner => {:login => "someOwner"},
        :parent => {:name => "someFork"}})
      @d.stub(:get_branches).with("someOwner/someFork").and_return([{:name => "master"}, {:name => "develop"}])
      @d.stub(:get_branches).with("#{@user}/someFork").and_return([{:name => "weeone_master"}, {:name => "weeone_develop"}])
      @d.is_merged?("someOwner/someFork").should be_false
    end

    it "returns false if some branches are not merged" do
      @m.stub(:login).and_return(@user)
      @d.stub(:get_repository).with("someOwner/someFork").and_return({:name => "someFork", 
        :owner => {:login => "someOwner"},
        :parent => {:name => "someFork"}})
      @d.stub(:get_branches).with("someOwner/someFork").and_return([{:name => "master"}, {:name => "develop"}])
      @d.stub(:get_branches).with("#{@user}/someFork").and_return([{:name => "someOwner_master"}, {:name => "weeone_master"}])
      @d.is_merged?("someOwner/someFork").should be_false
    end
    
    it "can handle it if the fork has a different name to the parent" do
      @m.stub(:login).and_return(@user)
      @d.stub(:get_repository).with("someOwner/someFork").and_return({:name => "someFork", 
        :owner => {:login => "someOwner"},
        :parent => {:name => "someToFork"}})
      # Fork branches 
      @d.stub(:get_branches).with("someOwner/someFork").and_return([{:name => "master"}, {:name => "develop"}])
      # Merged branches
      @d.stub(:get_branches).with("#{@user}/someToFork").and_return([{:name => "someOwner_master"}, {:name => "someOwner_develop"}])
      @d.is_merged?("someOwner/someFork").should be_true
    end
  
    it "looks at a specified repo if pointed at it" do
      @m.stub(:login).and_return(@user)
      @d.stub(:get_repository).with("someOwner/someFork").and_return({:name => "someFork", 
        :owner => {:login => "someOwner"},
        :parent => {:name => "someFork"}})
      # Fork branches 
      @d.stub(:get_branches).with("someOwner/someFork").and_return([{:name => "master"}, {:name => "develop"}])
      # Merged branches
      @d.stub(:get_branches).with("#{@user}/someFork").and_return([{:name => "someOwner_master"}, {:name => "someOwner_develop"}])
      @d.is_merged?("someOwner/someFork", "thewalrus/someFork").should be_true
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

    it "creates a specified fork when it doesn't already exist and return it" do
      # return no forks
      @m.stub(:repositories).and_return([])
      @m.should_receive(:fork).with("thewalrus/Trance")
      @m.stub(:repositories).and_return([{:full_name => "depUser/Trance"}])
      repo = {:name => "Trance", :full_name => "thewalrus/Trance"}
      @m.stub(:repository).with("thewalrus/Trance").and_return(repo)
      @m.stub(:repository).with("depUser/Trance").and_return(@dep_repo)
      @m.stub(:login).and_return(@user)
      @d.get_or_create_fork("someUser/Trance", "thewalrus/Trance").should == @dep_repo
    end

  end

  # describe ".archive_branch" do
  #     it "should archive the branch" do
  #       branch = mock(Grit::Remote, :name => "someUser/develop")
  #       git = mock(Grit::Git)
  #       repo = mock(Grit::Repo)
  #       gpath = create_temp_repo(File.join(File.dirname(__FILE__), *%w[dot_git]))
  #       repo.stub!(:new).with(gpath)
  #       repo.stub!(:git).and_return(git)
  #       git.should_receive(:branch).with({}, "someUser_develop", "someUser/develop")
  #       git.should_receive(:push).with({:timeout => @d.instance_variable_get("@timeout")}, 
  #         "depUser", 
  #         "someUser_develop")
  #       @m.stub(:login).and_return(@user)
  #       @d.archive_branch("some_path", branch)
  #     end
  #   end
  
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