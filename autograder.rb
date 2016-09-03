#!/usr/bin/env ruby

require 'sinatra'
require 'json'

configure do
  set :server, :puma
end

class AutoGrader < Sinatra::Base
  get '/' do
    'It lives!'
  end

  post '/github_webhooks' do
    request.body.rewind
    content = request.body.read
    # Ensure the signature matches.
    verify_signature(content)
    event = request.env['HTTP_X_GITHUB_EVENT']
    # Only handle push events for now.
    handle_push(data) if event == 'push'
    ''
  end

  private
  HMAC_DIGEST = OpenSSL::Digest.new('sha1')

  def verify_signature(content)
    secret = ENV['GITHUB_WEBHOOKS_SECRET']
    sig = 'sha1=' + OpenSSL::HMAC.hexdigest(HMAC_DIGEST, secret, content)
    rsig = request.env['HTTP_X_HUB_SIGNATURE']
    halt(400, "Invalid signature") unless Rack::Utils.secure_compare(sig, rsig)
  end

  def handle_push(push)
    puts 'What up, push?'
  end

  run! if app_file == $0
end

# vim: set sw=2 sts=2 ts=8 expandtab:
