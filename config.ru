#!/usr/bin/env ruby

# load env from .env
require 'dotenv/load'

require 'rubygems'
require 'gollum/app'

require 'tmpdir'
require 'fileutils'
require 'uri'

def add_auth_to_uri(uri, username, password)
  parsed = URI.parse(uri)
  parsed.userinfo = username + ':' + password
  parsed.to_s
end

def log(str)
  puts "\n> #{str}\n\n"
end

GIT_URL = ENV.fetch('GIT_URL')
GIT_USERNAME = ENV.fetch('GIT_USERNAME')
GIT_PASSWORD = ENV.fetch('GIT_PASSWORD')

GIT_AUTHOR_NAME = ENV.fetch('GIT_AUTHOR_NAME')
GIT_AUTHOR_EMAIL = ENV.fetch('GIT_AUTHOR_EMAIL')

HTTP_USERNAME = ENV.fetch('HTTP_USERNAME')
HTTP_PASSWORD = ENV.fetch('HTTP_PASSWORD')

WIKI_OPTIONS = {
  universal_toc: true,
  live_preview: false,
  collapse_tree: true,
  h1_title: true
}

authed_git_url = add_auth_to_uri(GIT_URL, GIT_USERNAME, GIT_PASSWORD)

tmpdir = Dir.mktmpdir

log 'Setting git author...'

`git config --global user.name "#{GIT_AUTHOR_NAME}"`
`git config --global user.email "#{GIT_AUTHOR_EMAIL}"`

log 'Cloning git repo...'

`cd #{tmpdir} && git clone #{authed_git_url} .`

log 'Starting Gollum...'

use Rack::Auth::Basic, 'auth required' do |username, password|
  [username, password] == [HTTP_USERNAME, HTTP_PASSWORD]
end

Gollum::Hook.register(:post_commit, :hook_id) do |committer, sha1|
  # Stash current changes so we can do our pull, rebase, push magic
  `cd #{tmpdir} && git stash`

  committer.wiki.repo.git.pull('origin', 'master', rebase: true)
  committer.wiki.repo.git.push('origin', 'master')

  # Get those changes back out there
  `cd #{tmpdir} && git stash apply --index`
end

Precious::App.set(:gollum_path, tmpdir)
Precious::App.set(:default_markup, :markdown)
Precious::App.set(:wiki_options, WIKI_OPTIONS)

run Precious::App

at_exit do
  FileUtils.rm_r tmpdir
end
