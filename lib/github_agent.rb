require 'octokit'
require 'yaml'

module GitHubAgent
  # To change this template use File | Settings | File Templates.

  def client
    @client ||= Octokit::Client.new({ access_token: token,
                                      per_page: 100,
                                      auto_paginate: true  })
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
      config = YAML::load_file(cf_file)
      config['access_token']
    else
      raise ConnectError, "Config file not found"
    end
  end

  def repo_shas(repo)
    client.branches(repo).collect {|x| x.commit.sha}
  end

  def get_branch_name(repo, sha)
    client.branches(repo).select {|x| x.commit.sha == sha}.first.name
  end

end