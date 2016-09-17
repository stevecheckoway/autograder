#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require_relative 'assignment'

unless ARGV.length == 4 || ARGV.length == 5
  $stderr.puts("Usage: #{$0} ASSIGNMENT_FILE OWNER REPO BRANCH [COMMIT_HASH]")
  exit(1)
end

assignment = AutoGrader::Assignment.load(ARGV[0])
owner  = ARGV[1]
repo   = ARGV[2]
branch = ARGV[3]
commit = ARGV[4]

unless assignment.match?(owner, repo, branch)
  puts("Repository \"#{owner}/#{repo}\" and branch \"#{branch}\" does not match assignment.")
  exit(1)
end

assignment.grade(owner, repo, branch, commit, log: $stdout)

# vim: set sw=2 sts=2 ts=8 expandtab:
