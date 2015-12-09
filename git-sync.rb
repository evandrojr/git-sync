#!/usr/bin/env ruby

require 'git'
require 'logger'



URI_GITHUB="https://github.com/evandrojr/legendario.git"
NAME_GITHUB="legendario"

URI_GITLAB="git@gitlab.com:evandrojr/legendario.git"
REMOTE_GITLAB="gitlab"

working_dir = '/tmp/checkout'

begin
  g = Git.clone(URI_GITHUB, NAME_GITHUB, :path => working_dir)
  g.config('user.name', 'Evandro Jr')
  g.config('user.email', 'evandrojr@gmail.com')
rescue=>error
  puts error.inspect
end

#g = Git.open(working_dir, :log => Logger.new(STDOUT))
g = Git.open(working_dir + "/legendario")
begin
  r = g.add_remote(REMOTE_GITLAB, URI_GITLAB)  # Git::Remote
  puts r.inspect
rescue=>error
    puts error.inspect
end

r = g.branches
puts r.inspect

r = g.pull('origin')
puts r.inspect

#Fazer para cada branch
g.push(g.remote(REMOTE_GITLAB))
