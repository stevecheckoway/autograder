#!/usr/bin/env ruby

require 'sinatra/base'
require 'json'
require 'yaml'

require_relative 'log'
require_relative 'gradejob'
require_relative 'grade'

module AutoGrader
  class AutoGrader < Sinatra::Base
    configure do
      use Rack::CommonLogger, ::AutoGrader.logger
      set :server, :puma
      File.open('config/secrets.yaml', 'r') do |f|
        set :secrets, YAML.safe_load(f.read, filename: 'config/secrets.yaml')
      end
    end

    helpers do
      def protected!
        return if authorized?
        headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
        halt(401, "Not authorized\n")
      end

      def authorized?
        @auth ||= Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? && @auth.basic? &&
          @auth.credentials == ['admin', settings.secrets['admin_password']]
      end
    end

    get '/status' do
      'Alive!'
    end

    get '/admin' do
      protected!
      grades = Grade.last(20).reverse
      erb :admin, locals: { grades: grades }
    end

    get '/output/:id' do |id|
      protected!
      begin
        grade = Grade.find(id)
      rescue ActiveRecord::RecordNotFound => ex
        halt(404, "Invalid output id")
      end
      content_type('text/plain')
      Zlib.inflate(grade.output)
    end

    post '/github_webhooks' do
      request.body.rewind
      content = request.body.read
      # Ensure the signature matches.
      verify_signature!(content)
      event = request.env['HTTP_X_GITHUB_EVENT']
      payload = JSON.parse(content)
      # Only handle push events for now.

      if event == 'push'
        owner  = payload['repository']['owner']['name']
        repo   = payload['repository']['name']
        branch = payload['ref']
        branch['refs/heads/'] = ''
        commit = payload['head_commit']['id']
        GradeJob.perform_async(owner, repo, branch, commit)
      end
      "#{event} response"
    end

    private
    HMAC_DIGEST = OpenSSL::Digest.new('sha1')

    def verify_signature!(content)
      secret = settings.secrets['github_webhooks_secret'] || ''
      sig = 'sha1=' + OpenSSL::HMAC.hexdigest(HMAC_DIGEST, secret, content)
      rsig = request.env['HTTP_X_HUB_SIGNATURE']
      unless Rack::Utils.secure_compare(sig, rsig)
        halt(400, "Invalid signature") unless Rack::Utils.secure_compare(sig, rsig)
      end
    end

    run! if app_file == $0
  end
end

# vim: set sw=2 sts=2 ts=8 expandtab:
