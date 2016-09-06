require 'fileutils'
require 'open3'
require 'shellwords'
require 'tmpdir'

class Workspace
  def initialize(repo)
    @path = Dir.mktmpdir(repo, File.dirname(__FILE__) + '/workspace')
    @cwd = @path
    @log = File.open(File.join(@path, '/output.log'), 'w')
    step('Create workspace: ' + @path)
  end

  def checkout(token, owner, repo, name, branch, ref)
    step("Check out #{owner}/#{repo} #{ref || branch} in directory #{name}")
    creds = File.open(File.join(@path, '/.gitcredentials'), 'w')
    creds.write("https://***:#{token}@github.com\n")
    creds.close
    
    url = "https://github.com/#{owner}/#{repo}.git"
    begin
      cmd('git', 'init', name)
      chdir(name) do
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
    log_exception(e)
    raise
  end

  def shellscript(path)
    step('Shell script ' + path)
    cmd('/bin/bash', '-x', '-e', File.join(@cwd, path))
  rescue Exception => e
    log_exception(e)
    raise
  end

  def read(path)
    step("Reading #{path}")
    File.read(File.join(@cwd, path))
  rescue Exception => e
    log_exception(e)
    raise
  end

  def cleanup(keep_ws)
    if keep_ws
      step("Keeping the workspace")
      @log.close
      @log = nil
    else
      step('Cleanup')
      @log.close
      @log = nil
      FileUtils.rm_rf(@path)
    end
  rescue Exception => e
    log_exception(e)
    raise
  end

  private
  def step(str)
    @log.puts("[Step] #{str}")
    f = File.open(File.join(@path, '.state'))
    f.puts(str)
    f.close
  end

  def cmd(*args)
    @log.puts("[Cmd] " + args.shelljoin)
    out, status = Open3.capture2(*args, chdir: @cwd)
    @log.puts(out)
    raise "#{args[0]} returned #{status}" unless status == 0
  end

  def chdir(dir)
    curr_cwd = @cwd
    begin
      @cwd = File.join(@cwd, dir)
      yield
    ensure
      @cwd = curr_cwd
    end
  end

  def log_exception(exception)
    @log.puts(exception.to_s)
    @log.close
    @log = nil
  end

end 

# vim: sw=2 sts=2 ts=8 expandtab
