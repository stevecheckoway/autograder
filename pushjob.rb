require 'sucker_punch'
require 'zlib'

require_relative 'assignment'
require_relative 'grade'
require_relative 'log'

SuckerPunch.logger = AutoGrader.logger

module AutoGrader
  class PushJob
    include SuckerPunch::Job
    workers 4
  
    def perform(data)
      owner  = data['repository']['owner']['name']
      repo   = data['repository']['name']
      branch = data['ref']
      commit = data['head_commit']['id']
      logger.info("Push for #{owner}/#{repo} on branch #{branch} at commit #{commit}")
  
      unless branch.start_with?('refs/heads/')
        logger.error("Unexpected ref \"#{branch}\" in push for #{owner}/#{repo}")
        return
      end
      branch['refs/heads/'] = ''
  
      if owner.include?('.') || owner.include?('/')
        logger.error("Unexpected character . or / in repository owner #{owner}")
        return
      end
      
      # Iterate through assignments in 'assignments/:owner/' and run the first
      # matching assignment.
      Dir[File.dirname(__FILE__) + "/assignments/#{owner}/*.yaml"].each do |path|
        assignment = Assignment.load(path)
        next if assignment.nil?
        next unless assignment.match?(repo, branch)
        logger.info("Running matching assignment #{path} on #{owner}/#{repo} #{branch}")
        log = StringIO.new('', 'w')
        begin
          success = assignment.grade(owner, repo, branch, commit, log: log)
          output = log.string
          status = success ? 'S' : 'F'
        rescue Exception => ex
          status = 'E'
	  output = log.string + ex.to_s
          logger.error(output)
        end
        log.close
        Grade.create(organization: owner,
                     assignment: assignment.assignment,
                     repository: repo,
                     commit: commit,
                     status: status,
                     output: Zlib.deflate(output))
        break
      end
    end
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:
