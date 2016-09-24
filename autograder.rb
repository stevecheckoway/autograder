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
      def protected!(organization)
        return if authorized?(organization)
        headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
        halt(401, "Not authorized\n")
      end

      def authorized?(organization)
        @auth ||= Rack::Auth::Basic::Request.new(request.env)
        return false unless @auth.provided? && @auth.basic?
        creds = @auth.credentials
        # Check for global admin, regardless of organization.
        return true if creds == ['admin', settings.secrets['admin_password']]
        # Check for organization admin.
        return false if organization.nil? || settings.secrets[organization].nil?
        creds == [organization, settings.secrets[organization]['admin_password']]
      end
    end

    get '/status' do
      'Alive!'
    end

    get '/admin' do
      protected!(nil)
      grades = Grade.last(20).reverse
      erb :admin, locals: { grades: grades, organization: nil }
    end

    get '/admin/:organization' do |organization|
      protected!(organization)
      grades = Grade.where(organization: organization).last(20).reverse
      erb :admin, locals: { grades: grades, organization: organization }
    end

    get '/output/:id' do |id|
      begin
        grade = Grade.find(id)
      rescue ActiveRecord::RecordNotFound => ex
        halt(404, "Invalid output id")
      end
      protected!(grade.organization)
      content_type('text/plain')
      Zlib.inflate(grade.output)
    end

    post '/github_webhooks' do
      request.body.rewind
      content = request.body.read
      # Ensure the signature matches.
      payload = JSON.parse(content)
      owner  = payload['repository']['owner']['name']
      verify_signature!(owner, content)
      event = request.env['HTTP_X_GITHUB_EVENT']
      # Only handle push events for now.

      if event == 'push'
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

    def verify_signature!(organization, content)
      org = settings.secrets[organization]
      secret = org && org['github_webhooks_secret'] || ''
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
