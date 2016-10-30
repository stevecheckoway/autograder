require 'fileutils'
require 'shellwords'
require 'tmpdir'

require_relative 'subprocess'

module AutoGrader
  class Workspace
    def initialize(repo, log)
      @path = Dir.mktmpdir(repo, File.dirname(__FILE__) + '/workspace')
      @cwd = @path
      if log.nil?
        @log = File.open(File.join(@path, '/output.log'), 'w')
      else
        @log = log
      end
      step('Create workspace: ' + @path)
    end
  
    def checkout(token, owner, repo, name, branch, ref)
      step("Check out #{owner}/#{repo} #{ref || branch} in directory #{name}")
      creds = File.open(File.join(@path, '/.gitcredentials'), 'w')
      creds.write("https://***:#{token}@github.com\n")
      creds.close
      
      begin
        url = "https://github.com/#{owner}/#{repo}.git"
        cmd('git', 'init', name)
        dir(name) do
          cmd('git', 'config', '--local', 'credential.username', '***')
          cmd('git', 'config', '--local', 'credential.helper', 'store --file=../.gitcredentials')
          if ref
            cmd('git', '-c', 'core.askpass=true', 'fetch', url, "#{branch}:refs/remotes/origin/#{branch}")
            cmd('git', 'checkout', '-f', ref)
          else
            cmd('git', '-c', 'core.askpass=true', 'fetch', '--depth=1', url, "#{branch}:refs/remotes/origin/#{branch}")
            cmd('git', 'checkout', "origin/#{branch}")
          end
          cmd('git', 'config', '--local', '--remove-section', 'credential')
        end
      ensure
        FileUtils.rm(creds.path)
      end
    rescue Exception => e
      @log.puts(e.to_s)
      raise
    end
  
    def shellscript(path, timeout: 120, delay: 1)
      step('Shell script ' + path)
      comment = []
      env = { 'PATH' => '/usr/local/bin:/usr/bin:/bin',
              'BASH_FUNC_comment%%' => '() { if [ $# -gt 0 ];then echo "$@" >&3;else cat >&3;fi }' }
      status = Subprocess.run('/bin/bash', '-x', '-e', path, fds: [:out, :err, 3],
                              chdir:@cwd, timeout: timeout, delay: delay,
                              env: env) do |fd, line|
        if fd == 3
          comment << line
        else
          @log.puts(line)
        end
      end
      comment = comment.join('').encode('UTF-8', undef: :replace, invalid: :replace, universal_newline: true)
      return status, comment
    rescue Exception => e
      @log.puts(e.to_s)
      raise
    end

    def docker(image, path, timeout: 120, delay: 10)
      step("Docker (#{image}) shell script #{path}")
      # Path relative to the workspace.
      relative = File.basename(@path)
      File.open(File.join(@path, 'wrapper.sh'), 'w') do |f|
        f.write <<-EOF
comment() {
  if [ $# -gt 0 ]; then
    echo "$@" >&3
  else
    cat >&3
  fi
}
export -f comment
timeout \
  --signal TERM \
  --kill-after #{delay.to_i} \
  #{timeout.to_i} \
  /bin/bash -x -e #{Shellwords.escape(path)} 3>.comment
        EOF
      end
      status = Subprocess.run('sudo',
                              "/usr/local/bin/run-#{image}.sh", relative, 'wrapper.sh',
                              fds: [:out, :err]) do |fd, line|
        @log.puts(line)
      end
      begin
        comment = File.read(File.join(@path, '.comment'))
        comment.encode!('UTF-8', undef: :replace, invalid: :replace, universal_newline: true)
      rescue
        comment = ''
      end
      return status, comment
    end
  
    def read(path)
      step("Reading #{path}")
      File.read(File.join(@cwd, path))
    rescue Exception => e
      @log.puts(e.to_s)
      raise
    end
  
    def cleanup(keep_ws)
      if keep_ws
        step("Cleanup: Keeping the workspace")
      else
        step('Cleanup')
        FileUtils.rm_rf(@path)
      end
    rescue Exception => e
      @log.puts(e.to_s)
      raise
    end
  
    private
    def step(str)
      @log.puts("[Step] #{str}")
      File.open(File.join(@path, '.state'), 'w') { |f| f.puts(str) }
    end
  
    def cmd(*args)
      @log.puts("[Cmd] " + args.shelljoin)
      status = Subprocess.run(*args, fds: [:out, :err], chdir: @cwd) do |fd, line|
        @log.puts(line)
      end
      raise "#{args[0]} #{status.to_s}" unless status.success?
    end
  
    def dir(path)
      curr_cwd = @cwd
      begin
        @cwd = File.join(@cwd, path)
        yield
      ensure
        @cwd = curr_cwd
      end
    end
  end 
end

# vim: sw=2 sts=2 ts=8 expandtab
