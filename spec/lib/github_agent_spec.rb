require 'rspec'
require_relative '../../lib/github_agent'

class FalseAgent
  include GitHubAgent
end

describe GitHubAgent do

  let(:agent) {FalseAgent.new}

  describe "#client" do

    before(:each) do
      agent.stub(:get_auth).and_return('1234')
    end

    it 'creates a client if it needs to' do
      Octokit::Client.should_receive(:new).once
      agent.client
    end

    it 'only creates a client once' do
      Octokit::Client.should_receive(:new).once
      agent.client
      agent.client
    end

    it 'uses the element arguments' do
      Octokit::Client.should_receive(:new).with(
          {access_token: '1234',
           per_page: 100,
           auto_paginate: true} )
      agent.client
    end

  end

  describe '#get_auth' do

    it 'raises an error if the config file is not found' do
      File.should_receive(:exist?).and_return(false)
      expect {agent.get_auth}.to raise_exception(AgentError)
    end

    it 'raises an error if the config file cannot be parsed' do
      YAML.should_receive(:load).and_raise(SyntaxError)
      expect {agent.get_auth}.to raise_exception(AgentError)
    end

    it 'raises an error if the config file does not have the access_token key' do
      YAML.should_receive(:load).and_return({})
      expect {agent.get_auth}.to raise_exception(AgentError)
    end

    it 'returns the config file values cannot be parsed' do
      YAML.should_receive(:load).and_return({'access_token' => "1234"})
      agent.get_auth.should eq("1234")
    end

    it 'can take the path to the config file as an argument' do
      File.should_receive(:exist?).with("/home/me/config.yml").and_return(true)
      YAML.should_receive(:load).and_return({'access_token' => "1234"})
      agent.get_auth("/home/me/config.yml").should eq("1234")
    end
  end

  describe "get_branch_name" do

    before(:each) do
      agent.stub(:get_auth).and_return('12345')
    end

    it 'returns the branch name' do
      agent.client
      .should_receive(:branches)
      .with("someOrg/SomeRepo")
      .and_return([double(name: 'somebranch', commit: double(sha: '1234')),
                   double(name: 'some_other_branch', commit: double(sha: '5432'))])
      agent.get_branch_name("someOrg/SomeRepo", '1234').should eq('somebranch')
    end

  end

  describe "repo_shas" do

    before(:each) do
      agent.stub(:get_auth).and_return('12345')
    end

    it 'returns the SHAs' do
      agent.client
        .should_receive(:branches)
        .with("someOrg/SomeRepo")
        .and_return([double(name: 'somebranch', commit: double(sha: '1234')),
                     double(name: 'some_other_branch', commit: double(sha: '5432'))])
      agent.repo_shas("someOrg/SomeRepo").should eq(%w(1234 5432))
    end
  end

end