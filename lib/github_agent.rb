require 'octokit'
require 'yaml'

class AgentError < Exception

end

module GitHubAgent
  # To change this template use File | Settings | File Templates.

  def client
    unless defined? @client
      @client = Octokit::Client.new({ access_token: token, per_page: 100, auto_paginate: true  })
    end
    @client
  end

  def token
    # get the token
    @token ||= get_auth
  end

  def get_auth(path='')
    # load the authentication info and return it
    if path == ''
      cf_file = File.join(File.dirname(__FILE__), '..', 'config', 'configuration.yml')
    else
      cf_file = path
    end
    if File.exist?(cf_file)
      # TODO: YAML Parse Error?
      begin
        config = YAML.load(cf_file)
        raise AgentError, "Token not found" unless not config['access_token'].nil?
        config['access_token']
      rescue SyntaxError
        raise AgentError, "Parsing Config file failed"
      end
    else
      raise AgentError, "Config file not found"
    end
  end

  def repo_shas(repo)
    client.branches(repo).collect {|x| x.commit.sha}
  end

  def get_branch_name(repo, sha)
    client.branches(repo).select {|x| x.commit.sha == sha}.first.name
  end

end