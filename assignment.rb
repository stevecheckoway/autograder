require 'logger'
require 'octokit'
require 'yaml'

require './workspace'

class Assignment
  def self.load(path)
    file = File.open(path, "r")
    data = file.read
    file.close
    config = YAML.safe_load(data, filename: path)
    require_params(path, config, 'token', 'assignment', 'branch', 'scriptfile')
    Assignment.new(config)
  end

  def self.require_params(path, config, *params)
    params.each do |param|
      if config[param].nil?
        raise "#{path}: missing required field \"#{param}\""
      end
    end
  end
  private_class_method :require_params

  def initialize(config)
    @config = config
  end

  def match?(repo, branch)
    repo.start_with?("#{@config['assignment']}-") && branch == @config['branch']
  end

  def grade(owner, repo, branch, commit)
    token = @config['token']
    repos = @config['repos'] || []
    
    ws = Workspace.new(repo)
    ws.checkout(token, owner, repo, 'code', branch, commit)
    repos.each do |r|
      if r.include?('/')
        extra_owner, extra_repo = r.split('/', 2)
      else
        extra_owner = owner
        extra_repo = r
      end
      ws.checkout(token, extra_owner, extra_repo, extra_repo, 'master', nil)
    end
    ws.shellscript(@config['scriptfile'])

    if @config['commentfile']
      body = ws.read(@config['commentfile'])
      body = "```\n@{body}\n```" if @config['codecomment']
      # XXX: Leave a comment on the commit.
    end

    ws.cleanup(@config['keep_ws'])
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:
