require 'logger'
require 'sucker_punch'

SuckerPunch.logger = Logger.new('push.log')
SuckerPunch.logger.level = Logger::INFO

class PushJob
  include SuckerPunch::Job
  workers 4

  def perform(data)
    owner  = data['repository']['owner']['name']
    repo   = data['repository']['name']
    branch = data['ref']
    commit = data['head_commit']['id']

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
      assignment.grade(owner, repo, branch, commit)
      break
    end
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:
