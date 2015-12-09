#!/usr/bin/env ruby

require 'git'
require 'logger'
require 'awesome_print'

sync = [
  {
     name: "noosfero",
     working_dir: "/tmp",
   #  branches: ['master'],
     origin: {
         uri:  "git@gitlab.com:noosfero/noosfero.git",
     },
     destinations: [
     {
       remote: "github-noosfero",
       uri: "git@github.com:evandrojr/noosfero.git",
     },
    #  {
    #    remote: "gitlab-lay-back-subs",
    #    uri: "git@gitlab.com:evandrojr/lay-back-subs.git",
    #  }
     ]
 },
 {
    name: "legendario",
    working_dir: "/tmp",
  #  branches: ['master'],
    origin: {
        uri:  "https://github.com/evandrojr/legendario.git",
    },
    destinations: [
    {
      remote: "gitlab-legendario",
      uri: "git@gitlab.com:evandrojr/legendario.git",
    },
    {
      remote: "gitlab-lay-back-subs",
      uri: "git@gitlab.com:evandrojr/lay-back-subs.git",
    }
    ]
  }

]



while true
  sync.each do |rep_map|
    ap rep_map
    if !File.exists? ("#{rep_map[:working_dir]}/#{rep_map[:name]}")
        g = Git.clone(rep_map[:origin][:uri], rep_map[:name], :path => rep_map[:working_dir])
        g.config('user.name', 'Evandro Jr')
        g.config('user.email', 'evandrojr@gmail.com')
    end

    #g = Git.open(working_dir, :log => Logger.new(STDOUT))
    g = Git.open(rep_map[:working_dir] + "/#{rep_map[:name]}")

    remotes = g.remotes.map { |r| r.to_s }
    ap remotes

    begin
      rep_map[:destinations].each do |dest|
        if !remotes.include? dest[:remote]
          ap g.add_remote(dest[:remote], dest[:uri])  # Git::Remote
        end
      end
    rescue=>error
        ap error
    end

    begin
       #rep_map[:branches].each do |branch|
       g.branches.remote.each do |branch|
         b = /[A-Z]$/i =~ branch.to_s
         `git fetch origin #{b}`
       end
     rescue=>error
         ap error
     end

   begin
      #rep_map[:branches].each do |branch|
      g.branches.local.each do |branch|
        ap g.checkout(branch)
        ap g.reset_hard
        ap g.pull('origin')
        rep_map[:destinations].each do |dest|
          ap g.push(g.remote(dest[:remote]))
        end
      end
    rescue=>error
        ap error
    end
  end #  sync.each do |rep_map|
  puts "Trying again in 5 minutes"
  sleep(5*60)

end # while
