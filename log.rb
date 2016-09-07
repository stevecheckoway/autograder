require 'logger'

module AutoGrader
  module_function
  def logger
    if @logger.nil?
      @logger = Logger.new('autograder.log', 10, 1024000)
      @logger.level = Logger::INFO
    end
    @logger
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:
