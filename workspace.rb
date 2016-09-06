require 'fileutils'
require 'open3'
require 'shellwords'
require 'tmpdir'

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
    
    url = "https://github.com/#{owner}/#{repo}.git"
    begin
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

  def shellscript(path)
    step('Shell script ' + path)
    cmd('/bin/bash', '-x', '-e', File.join(@cwd, path), return_status: true)
  rescue Exception => e
    @log.puts(e.to_s)
    raise
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

  def cmd(*args, return_status: false)
    @log.puts("[Cmd] " + args.shelljoin)
    out, status = Open3.capture2(*args, chdir: @cwd)
    @log.puts(out) if out.length > 0
    return status if return_status
    raise "#{args[0]} returned #{status}" unless status == 0
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
# vim: sw=2 sts=2 ts=8 expandtab
