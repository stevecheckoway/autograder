require 'logger'
require 'octokit'
require 'yaml'

require_relative 'workspace'

module AutoGrader
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

    def assignment
      @config['assignment']
    end

    def match?(organization, repo, branch)
      organization == @config['organization'] &&
      repo.start_with?("#{@config['assignment']}-") &&
      branch == @config['branch']
    end

    def grade(owner, repo, branch, commit, log: nil)
      token = @config['token']
      repos = @config['repos'] || []
      full_name = "#{owner}/#{repo}"
      client = Octokit::Client.new(access_token: token)
      status_options = { context: 'autograder', description: 'Autograding about to begin' }
      client.create_status(full_name, commit, 'pending', status_options)
      status = nil
      ws = Workspace.new(repo, log)
      comment = nil
      desc = ''
      begin
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
        timeout = @config['timeout'] || 120
        delay = @config['delay'] || 1
        if @config['docker']
          status, comment = ws.docker(@config['docker'], @config['scriptfile'], timeout: timeout, delay:delay)
        else
          status, comment = ws.shellscript(@config['scriptfile'], timeout:timeout, delay:delay)
        end
      ensure
        if status.nil?
          state = 'error'
          desc = 'Autograder grading script error'
        elsif status.signaled?
          state = 'failure'
          desc = 'Autograding tests timed out or were killed'
        elsif status.success?
          state = 'success'
          desc = 'All autograding tests passed successfully'
        else
          state = 'failure'
          desc = 'One or more autograding tests failed'
        end
        url = "https://github.com/#{full_name}/commit/#{commit}"
        status_options = { context: 'autograder', description: desc, target_url: url }
        client.create_status(full_name, commit, state, status_options)
        ws.cleanup(@config['keep_ws'])
      end

      # Add comment to commit.
      if comment.nil?
        body = desc
      else
        body = "#{desc}:\n#{comment}"
      end
      body = "```\n#{body}\n```" if @config['codecomment']
      client.create_commit_comment(full_name, commit, body)
      !status.nil? && status.success?
    end
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:
