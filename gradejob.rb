require 'sucker_punch'
require 'zlib'

require_relative 'assignment'
require_relative 'grade'
require_relative 'log'

SuckerPunch.logger = AutoGrader.logger

module AutoGrader
  class GradeJob
    include SuckerPunch::Job
    workers 4
  
    def perform(owner, repo, branch, commit)
      logger.info("Push for #{owner}/#{repo} on branch #{branch} at commit #{commit}")
  
      if owner.include?('.') || owner.include?('/')
        logger.error("Unexpected character . or / in repository owner #{owner}")
        return
      end
      
      # Iterate through assignments in 'assignments/:owner/' and
      # 'assignments/' and run the first matching assignment.
      dir = File.join(File.dirname(__FILE__), 'assignments')
      globs = [File.join(dir, "#{owner}/*.yaml"), File.join(dir, '*.yaml')]
      Dir.glob(globs).each do |path|
        assignment = Assignment.load(path)
        next if assignment.nil?
        next unless assignment.match?(owner, repo, branch)
        logger.info("Running matching assignment #{path} on #{owner}/#{repo} #{branch}")
        grade = Grade.create(organization: owner,
                             assignment: assignment.assignment,
                             repository: repo,
                             branch: branch,
                             commit: commit,
                             status: 'R',
                             output: nil)
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
        logger.info("Grading #{owner}/#{repo} #{branch} finished with status #{status}")
        # Update the database
        grade.status = status
        grade.output = Zlib.deflate(output)
        grade.save
        break
      end
    end
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:
