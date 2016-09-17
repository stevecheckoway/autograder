# Run a subprocess with a line-oriented stdout, stderr, and other output
# descriptors and an optional timeout.

module Subprocess
  def self.run(*args, fds: [], env: nil, chdir: nil, timeout: nil, delay: 1, &block)
    # Check arguments.
    if fds.include?(:in) || fds.include?(0)
      raise 'fds may not include stdin (0 or :in)'
    end
    unless fds.empty? || block_given?
      raise 'A block must be provided when fds is not empty.'
    end

    opts = {}
    pipe_map = {}
    close_pipes = []

    # Add the environment hash at the beginning of args for Process.spawn, if
    # present. Set the current directory if present.
    args.unshift(env) unless env.nil?
    opts[:chdir] = chdir unless chdir.nil?

    # Create pipes for each file descriptor specified in the fds.
    fds.each do |fd|
      out_r, out_w = IO.pipe
      pipe_map[out_r] = ['', fd]
      opts[fd] = out_w
      close_pipes << out_w
    end

    # Close stdin.
    opts[:in] = :close
    opts[:pgroup] = true

    # Start the process and close the ends of the pipes not necessary in the
    # parent.
    start_time = Time.now
    pid = Process.spawn(*args, opts)
    close_pipes.each { |pipe| pipe.close }

    status = nil
    loop do
      # Break out of the loop if the process has exited.
      _, status = Process.wait2(pid, Process::WNOHANG)
      break unless status.nil?

      # Check for timeout.
      if timeout && timeout > 0
        remaining = timeout - (Time.now - start_time)
        if remaining <= 0
          # The time has passed, send SIGTERM unless we've already sent
          # SIGTERM in which case we send SIGKILL.
          if delay > 0
            Process.kill('TERM', -pid)
            start_time = Time.now
            timeout = delay
            delay = 0
            next
          else
            Process.kill('KILL', -pid)
            _, status = Process.wait2(pid)
            break
          end
        end
      else
        remaining = nil
      end

      # If there is nothing remaining to read and there's no timeout, break
      # out of the loop. We're done here. If there's nothing to read but
      # there's still a timeout, begin polling at half second intervals.
      if pipe_map.empty?
        if remaining.nil?
          _, status = Process.wait2(pid)
          break
        end
        remaining = 1 if remaining > 1
      end

      # Sleep until there is some output to read or remaining seconds have
      # passed.
      result = IO.select(pipe_map.keys, [], [], remaining)
      next if result.nil?

      # For each pipe, read some data
      result[0].each { |pipe| read_from_pipe(pipe, pipe_map, &block) }
    end

    # The only way to exit the loop is for the process to have ended and we
    # have waited on the child. Read the rest of the data from any remaining
    # pipes.
    until pipe_map.empty?
      pipe_map.each { |pipe, _| read_from_pipe(pipe, pipe_map, &block) }
    end
    status
  end

  def self.read_from_pipe(pipe, pipe_map)
    begin
      # Append data read from the pipe to whatever has been read before,
      # split into lines, and call passed in lambda on each complete line.
      partial, fd = pipe_map[pipe]
      partial << pipe.sysread(4096)
      lines = partial.split("\n", -1)
      pipe_map[pipe][0] = lines.pop
      lines.each { |line| yield(fd, line + "\n") }
    rescue EOFError
      # Send partial string, if any, and remove from the pipe_map.
      partial, fd = pipe_map.delete(pipe)
      yield(fd, partial) unless partial.empty?
      pipe.close
    end
    nil
  end
  private_class_method :read_from_pipe
end

# vim: set sw=2 sts=2 ts=8 expandtab:
