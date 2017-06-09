#!/usr/bin/env ruby

# load env from .env
require 'dotenv/load'

require 'rubygems'
require 'gollum/app'
require 'sinatra/base'

require 'thread'
require 'tmpdir'
require 'fileutils'
require 'uri'
require 'json'

# for dev conveniance
require 'byebug'

module Util
  @@git_mutex = Mutex.new

  def self.add_auth_to_uri(uri, username, password)
    parsed = URI.parse(uri)
    parsed.userinfo = username + ':' + password
    parsed.to_s
  end

  def self.log(str)
    puts "\n> #{str}\n\n"
  end

  def self.update_repo(git_dir)
    Thread.new do
      @@git_mutex.synchronize do
	# Stash current changes so we can do our pull, rebase, push magic
	`cd #{git_dir} && git stash`

	# Pull, rebase, and push
	`cd #{git_dir} && git pull --rebase`
	`cd #{git_dir} && git push`

	# Get those changes back out there
	`cd #{git_dir} && git stash apply --index`
      end
    end
  end
end

class WebhookMiddleware < Sinatra::Base
  def initialize(app, opts)
    @next = app
    @git_dir = opts.delete(:git_dir)
    @webhook_secret = opts.delete(:webhook_secret)

    super()
  end

  post '/gh_webhook' do
    Util.log 'Receiving GitHub webhook...'

    request.body.rewind
    payload_body = request.body.read

    verify_signature(payload_body)

    payload = JSON.parse(params[:payload], symbolize_names: true)
    event = request.env['HTTP_X_GITHUB_EVENT']

    if event == 'push'
      Util.log 'Is push event! Updating repo.'
      Util.update_repo(@git_dir)
    else
      Util.log 'Not a push event, ignoring.'
    end

    status 200
  end

  def verify_signature(payload_body)
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha1'), @webhook_secret, payload_body
    )

    unless Rack::Utils.secure_compare(
	signature, request.env['HTTP_X_HUB_SIGNATURE']
    )
      Util.log 'Webhook secret did not match! Rejecting.'
      return halt 500, "Signatures didn't match!"
    end
  end

  # Pass all other requests to the app
  get '/*' do @next.call(request.env) end
  post '/*' do @next.call(request.env) end
  put '/*' do @next.call(request.env) end
  patch '/*' do @next.call(request.env) end
  delete '/*' do @next.call(request.env) end
  options '/*' do @next.call(request.env) end
  link '/*' do @next.call(request.env) end
  unlink '/*' do @next.call(request.env) end
end

GIT_URL = ENV.fetch('GIT_URL')
GIT_USERNAME = ENV.fetch('GIT_USERNAME')
GIT_PASSWORD = ENV.fetch('GIT_PASSWORD')

GIT_AUTHOR_NAME = ENV.fetch('GIT_AUTHOR_NAME')
GIT_AUTHOR_EMAIL = ENV.fetch('GIT_AUTHOR_EMAIL')

HTTP_USERNAME = ENV.fetch('HTTP_USERNAME')
HTTP_PASSWORD = ENV.fetch('HTTP_PASSWORD')

GH_WEBHOOK_SECRET = ENV.fetch('GH_WEBHOOK_SECRET')

WIKI_OPTIONS = {
  universal_toc: true,
  live_preview: false,
  collapse_tree: true,
  h1_title: true
}

authed_git_url = Util.add_auth_to_uri(GIT_URL, GIT_USERNAME, GIT_PASSWORD)

tmpdir = Dir.mktmpdir

Util.log 'Setting git author...'

`git config --global user.name "#{GIT_AUTHOR_NAME}"`
`git config --global user.email "#{GIT_AUTHOR_EMAIL}"`

Util.log 'Cloning git repo...'

`cd #{tmpdir} && git clone #{authed_git_url} .`

Util.log 'Starting Gollum...'

Gollum::Hook.register(:post_commit, :hook_id) do |committer, sha1|
  Util.update_repo(tmpdir)
end

Precious::App.set(:gollum_path, tmpdir)
Precious::App.set(:default_markup, :markdown)
Precious::App.set(:wiki_options, WIKI_OPTIONS)

# Catch GitHub webhooks
use WebhookMiddleware, git_dir: tmpdir, webhook_secret: GH_WEBHOOK_SECRET

# Require auth
use Rack::Auth::Basic, 'auth required' do |username, password|
  [username, password] == [HTTP_USERNAME, HTTP_PASSWORD]
end

# The app itself
run Precious::App

at_exit do
  FileUtils.rm_r tmpdir
end
