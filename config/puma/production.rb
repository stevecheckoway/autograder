#!/usr/bin/env puma

basedir = File.expand_path('../..', File.dirname(__FILE__))
rootdir = basedir
logdir = File.join(rootdir, '/var/log')

directory(basedir)
rackup(File.join(basedir, 'config.ru'))
environment('production')
daemonize(true)

pidfile(File.join(rootdir, '/var/run/autograder/autograder.pid'))
state_path(File.join(rootdir, '/var/run/autograder/state'))
stdout_redirect(File.join(logdir, 'stdout.log'),
		File.join(logdir, 'stderr.log'), true)
threads(0, 16)

bind('unix:///tmp/autograder.sock')

activate_control_app
