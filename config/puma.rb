#!/usr/bin/env puma

basedir = File.expand_path('..', File.dirname(__FILE__))
rootdir = basedir

directory(basedir)
rackup(File.join(basedir, 'config.ru'))

pidfile(File.join(rootdir, '/var/run/autograder/autograder.pid'))
state_path(File.join(rootdir, '/var/run/autograder/state'))
threads(0, 16)
activate_control_app
