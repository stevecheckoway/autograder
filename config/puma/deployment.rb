root = "#{Dir.getwd}"

stdout_redirect 'stdout.log', 'stderr.log', true
bind "unix:///tmp/autograder.sock"
pidfile "#{root}/tmp/puma/pid"
state_path "#{root}/tmp/puma/state"
rackup "#{root}/config.ru"

threads 4, 8

activate_control_app
daemonize true
