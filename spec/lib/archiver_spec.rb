require_relative '../spec_helper'
require 'octokit'
require 'grit'
require_relative '../../lib/archiver'

describe Archiver do

  subject(:archiver) {Archiver.new(options)}
  let(:options){{timeout: 320, source: "", repository: fork_full_name}}
  let(:fork){double("Fork Repository",
                    name: fork_name,
                    full_name: fork_full_name,
                    parent: double(full_name: fork_parent),
                    owner: double(login: fork_owner),
                    rels: {
                        ssh: double(href: "git@github.com:#{fork_full_name}.git"),
                        git: double(href: "git://github.com/#{fork_full_name}.git"),
                    })
            }
  let(:fork_parent) {double("Fork Parent",
                            full_name: "someOrg/#{fork_name}",
                            name: fork_name,
                            rels: {
                                ssh: double(href: "git@github.com:someOrg/#{fork_name}.git"),
                                git: double(href: "git://github.com/someOrg/#{fork_name}.git"),
                            })}
  let(:archive) {double(name: 'SomeRepo',
                        full_name: "#{client.user.login}/SomeRepo",
                        owner: double(login: client.user.login),
                        rels: {
                            ssh: double(href: "git@github.com:#{client.user.login}/SomeRepo.git"),
                            git: double(href: "git://github.com/#{client.user.login}/SomeRepo.git"),
                        })}
  let(:client) {double('client', user: user)}
  let(:user) {double('user', login: 'archiver')}
  let(:fork_name) {'Repo'}
  let(:fork_full_name) {"#{fork_owner}/#{fork_name}"}
  let(:fork_owner) {"someOwner"}

  before(:each) do
    archiver.stub(:client).and_return(client)
    archiver.stub(:repo_exists?).and_return(true)
  end

  describe "#fork_repository" do

    it "returns the fork" do
      client.should_receive(:repo).with(fork_full_name).and_return(fork)
      archiver.fork_repository.should eq(fork)
    end

    it 'caches the lookup' do
      client.should_receive(:repo).once
      archiver.fork_repository
      archiver.fork_repository
    end
  end

  describe "#validates?" do

    it 'validates a fork' do
      client.stub(:repo).and_return(double(fork: true))
      archiver.validates?.should be_true
    end

    it 'does not validate a non-fork' do
      client.stub(:repo).and_return(double(fork: false))
      archiver.validates?.should be_false
    end

  end

  describe "#branches_to_archive" do
    before(:each) do
      archiver.stub(:fork_repository).and_return(fork)
      archiver.stub(:archive_repository).and_return(archive)
    end

    it "returns an empty Array if there are none to archive" do
      archiver.should_receive(:repo_shas).and_return(%w(1234), %w(1234))
      archiver.branches_to_archive.empty?.should be_true
    end

    it "returns an Array with the SHAs to archive" do
      archiver.should_receive(:repo_shas).and_return(%w(1234 4321), %w(1234))
      archiver.branches_to_archive.should eq(%w(4321))
    end

    it "returns an Array with the SHAs to archive with extras" do
      archiver.should_receive(:repo_shas).and_return(%w(1234 4321), %w(1234 5467))
      archiver.branches_to_archive.should eq(%w(4321))
    end
  end

  describe '#needs_archiving?' do

    before(:each) do
      archiver.stub(:fork_repository).and_return(fork)
      archiver.stub(:parent_repository).and_return(fork_parent)
    end

    it 'returns false if all shas are represented on the archive' do
      archiver.stub(:branches_to_archive).and_return([])
      archiver.needs_archiving?.should be_false
    end
    it 'returns true if all shas are represented on the archive' do
      archiver.stub(:branches_to_archive).and_return(%w(4321))
      archiver.needs_archiving?.should be_true
    end
  end

  describe "#clone" do

    before(:each) do
      archiver.stub(:fork_repository).and_return(fork)
      archiver.stub(:archive_repository).and_return(archive)
      archiver.stub(:parent_repository).and_return(fork_parent)
    end

    it 'clones the repository locally if it does not exist' do
      grit = double("Grit::Git")
      grit.stub(:clone)
      Grit::Git.stub(:new).and_return(grit)
      clone = double("Grit::Repo")
      client.stub(:user).and_return(double(login: user.login))
      clone.should_receive(:remote_add).with(fork.owner.login,
                                             fork.rels[:ssh].href)
      clone.stub(:remote).and_return(double(fetch: nil))
      git = double("git")
      git.should_receive(:fetch)
      clone.should_receive(:git).and_return(git)
      Grit::Repo.stub(:new).and_return(clone)
      archiver.clone.should eq(clone)
    end

    it 'reuses an existing clone' do
      grit = double("Grit::Git")
      grit.stub(:clone)
      Grit::Git.stub(:new).and_return(grit)
      clone = double("Grit::Repo")
      client.stub(:user).and_return(double(login: user.login))
      clone.should_receive(:remote_add).once
      clone.stub(:remote).and_return(double(fetch: nil))
      git = double("git")
      git.should_receive(:fetch)
      clone.should_receive(:git).once.and_return(git)
      Grit::Repo.stub(:new).and_return(clone)
      archiver.clone
      archiver.clone
    end


    it 'raises an exception if there is a timeout on clone' do
      grit = double("Grit::Git")
      grit.stub(:clone).and_raise(Grit::Git::GitTimeout)
      Grit::Git.stub(:new).and_return(grit)
      expect { archiver.clone }.to raise_exception(ArchivingError)
    end

    it 'raises an exception if there is a timeout on fetch' do
      grit = double("Grit::Git")
      grit.stub(:clone)
      Grit::Git.stub(:new).and_return(grit)
      clone = double("Grit::Repo")
      client.stub(:user).and_return(double(login: user.login))
      clone.should_receive(:remote_add).once
      clone.stub(:remote).and_return(double(fetch: nil))
      git = double("git")
      git.should_receive(:fetch).and_raise(Grit::Git::GitTimeout)
      clone.should_receive(:git).once.and_return(git)
      Grit::Repo.stub(:new).and_return(clone)
      expect { archiver.clone }.to raise_exception(ArchivingError)
    end

  end

  describe "#copy_branch" do
    let(:clone) {double("Git::Base")}

    before(:each) do
      archiver.stub(:fork_repository).and_return(fork)
      archiver.stub(:archive_repository).and_return(archive)
      archiver.stub(:clone).and_return(clone)
    end

    it 'copies the branch to the cloned repository if it does not exist' do
      # archive branches
      client.stub(:branches).with(archive.full_name).and_return([double(name: "someone_master",
                                                                        commit: double(sha: '1234')),
                                                                 double(name: "someone_develop",
                                                                        commit: double(sha: '4321'))])
      # client branches
      client.stub(:branches).with(fork.full_name).and_return([double(name: "master",
                                                                     commit: double(sha: '2323')),
                                                              double(name: "develop",
                                                                     commit: double(sha: '3333'))])
      git = double("git")
      git.should_receive(:branch).with({}, "someOwner_master", '2323')
      git.should_receive(:push)
      clone.should_receive(:git).twice.and_return(git)
      archiver.copy_branch('2323')
    end

    it 'does not copies the branch to the cloned repository if it exists' do
      client.stub(:branches).with(archive.full_name).and_return([double(name: "#{fork_owner}_master",
                                                                        commit: double(sha: '1234')),
                                                                 double(name: "someone_develop",
                                                                        commit: double(sha: '4321'))])
      # branch exists, eject
      client.should_not_receive(:branches).with(fork_full_name)
      archiver.copy_branch('1234')
    end

    it 'raises an error on push timeout' do
      # archive branches
      client.stub(:branches).with(archive.full_name).and_return([double(name: "someone_master",
                                                                        commit: double(sha: '1234')),
                                                                 double(name: "someone_develop",
                                                                        commit: double(sha: '4321'))])
      # client branches
      client.stub(:branches).with(fork.full_name).and_return([double(name: "master",
                                                                     commit: double(sha: '2323')),
                                                              double(name: "develop",
                                                                     commit: double(sha: '3333'))])
      git = double("git")
      git.should_receive(:branch).with({}, "someOwner_master", '2323')
      git.should_receive(:push).and_raise(Grit::Git::TimeoutError)
      clone.should_receive(:git).twice.and_return(git)
      expect {archiver.copy_branch('2323')}.to raise_exception(ArchivingError)

    end
  end

  describe "#archive" do

    it 'archives a repository that needs archiving' do
      archiver.should_receive(:validates?).and_return(true)
      archiver.should_receive(:branches_to_archive).twice.and_return(%w(1234))
      archiver.should_receive(:copy_branch).with('1234')
      archiver.archive
    end

    it 'does not archive a repository that has been archived' do
      archiver.should_receive(:validates?).and_return(true)
      archiver.should_receive(:branches_to_archive).and_return([])
      archiver.should_not_receive(:copy_branch)
      archiver.archive
    end
  end

  describe "#has_similar_branches?" do

    before(:each) do
      archiver.stub(:fork_repository).and_return(fork)
    end

    it 'returns true when there are branches that are not unique' do
      branches = [double(name: 'someBranch'),
                  double(name: 'SomeBranch'),
                  double(name: 'Somebranch')]
      client.should_receive(:branches).and_return(branches)
      archiver.has_similar_branches?.should be_true
    end

    it 'returns false when there are no branches that are not unique' do
      branches = [double(name: 'some_Branch'),
                  double(name: 'SomeBranch'),
                  double(name: 'Somebranchname')]
      client.should_receive(:branches).and_return(branches)
      archiver.has_similar_branches?.should be_false
    end

  end

  describe "#archive_branch_name" do
    let(:fork) {double(name: 'someRepo',
                       full_name: fork_full_name,
                       owner: double(login: 'someOwner'))}
    before(:each) do
      archiver.stub(:has_similar_branches?).and_return(false)
      archiver.stub(:fork_repository).and_return(fork)
    end

    it "maps the fork branch to a converged name" do
      archiver.archive_branch_name('someBranch').should eq('someOwner_someBranch')
    end

    it "maps the fork branch with a / to a converged name" do
      archiver.archive_branch_name('feature/SomeFeature').should eq('someOwner_feature/SomeFeature')
    end

    it 'qualifies a case insensitive name in a consistent way' do
      archiver.stub(:has_similar_branches?).and_return(true)
      branches = [double(name: 'someBranch'),
                  double(name: 'SomeBranch'),
                  double(name: 'Somebranch')]
      client.should_receive(:branches).and_return(branches)
      archiver.archive_branch_name('Somebranch').should eq('someOwner_Somebranch_1')
    end

  end

  describe "#branch_name_exists?" do
    let(:archive){double(full_name: "#{client.user.login}/SomeRepo")}

    before(:each) do
      archiver.stub(:repo_exists?).and_return(true)
      archiver.stub(:fork_repository).and_return(fork)
      archiver.stub(:archive_repository).and_return(archive)
    end

    it "returns true if the branch name exists on the departed user fork" do
      archive_branches = [double(name: 'someOwner_SomeBranch'), double(name: 'otherOwner_SomeBranch')]
      client.should_receive(:branches).with('archiver/SomeRepo').and_return(archive_branches)
      archiver.branch_name_exists?('someOwner_SomeBranch').should be_true
    end
    it "returns false if the branch name does not exist on the departed user fork" do
      archive_branches = [double(name: 'otherOwner_SomeBranch')]
      client.should_receive(:branches).with('archiver/SomeRepo').and_return(archive_branches)
      archiver.branch_name_exists?('someOwner_SomeBranch').should be_false
    end
  end

  describe "#parent_repostitory" do

    before(:each) do
      archiver.stub(:repo_exists?).and_return(true)
      archiver.stub(:fork_repository).and_return(fork)
    end

    it "identifies the parent from the fork" do
      parent = double(name: fork_name, full_name: fork_parent)
      client.should_receive(:repo).with(fork_parent).and_return(parent)
      archiver.parent_repository.should eq(parent)
    end

    it 'caches the lookup' do
      client.should_receive(:repo).once
      archiver.parent_repository
      archiver.parent_repository
    end

  end

  describe "#archive_repository" do

    before(:each) do
      archiver.stub(:repo_exists?).and_return(true)
      archiver.stub(:fork_repository).and_return(fork)
    end

    it 'returns the archive if it exists' do
      archive = double(name: fork_name,
                       full_name: "#{client.user.login}/#{fork_name}")
      client.should_receive(:repositories).and_return([archive])
      client.should_receive(:repo).with("#{client.user.login}/#{fork_name}").and_return(archive)
      archiver.archive_repository.should eq(archive)
    end

    it 'fork the repository if the archive does not exist' do
      archive = double(name: fork_name,
                       full_name: "#{client.user.login}/#{fork_name}")
      client.should_receive(:repositories).and_return([double(name: 'aaa')],
                                                      [double(name: 'aaa'), archive])
      client.should_receive(:fork).with(fork_parent)
      client.should_receive(:repo).with("#{client.user.login}/#{fork_name}").and_return(archive)
      archiver.archive_repository.should eq(archive)
    end

    it 'caches the lookup' do
      archive = double(name: fork_name,
                       full_name: "#{client.user.login}/#{fork_name}")
      client.should_receive(:repositories).once.and_return([archive])
      client.should_receive(:repo).once
      archiver.archive_repository
      archiver.archive_repository
    end

  end

  #describe "#repo_exists?" do
  #  it "returns true if the repository exists" do
  #    client.should_receive(:repo).with(fork_full_name).and_return({name: 'Repo', full_name: fork_full_name})
  #    archiver.repo_exists?(fork_full_name).should be_true
  #  end
  #
  #  it "returns false if the repository doesn't exist" do
  #    client.should_receive(:repo).with(fork_full_name).and_raise(Octokit::NotFound)
  #    archiver.repo_exists?(fork_full_name).should be_false
  #  end
  #end

end