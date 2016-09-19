#!/usr/bin/env puma

directory(File.expand_path('../..', File.dirname(__FILE__)))
rackup('config.ru')

daemonize(true)
pidfile('/var/run/autograder/autograder.pid')
state_path('/var/run/autograder/state')
stdout_redirect('/var/log/autograder/autograder.log',
		'/var/log/autograder/autograder.err', true)

threads(0, 16)

bind('unix:///var/run/autograder/autograder.sock')

activate_control_app
