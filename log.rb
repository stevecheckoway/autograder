require 'logger'

Logger.class_eval { alias :write :'<<' }

module AutoGrader
  module_function
  def logger
    @logger ||= begin
      logger = Logger.new($stdout)
      logger.level = Logger::INFO
      logger
    end
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:
