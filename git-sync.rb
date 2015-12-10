#!/usr/bin/env ruby

require 'git'
require 'logger'
require 'awesome_print'
require 'yaml'

include FileUtils

sync =  YAML.load(File.read('sync.yaml'))

def shell_execute(command, silent = false)
    puts command unless silent
    o = `#{command}`
    r = $?.to_i
    if r!=0
      puts "Error: #{o} code :#{r}"
    end
    r
end

shell_execute('git config --global url."https://".insteadOf git://', true)

while true
  sync[:maps].each do |rep_map|
    puts "+++++++++++ Synchronizing mapping: +++++++++++"
    puts rep_map.to_yaml
    puts ""
    dir = "#{rep_map[:working_dir]}/#{rep_map[:name]}"
    if !File.exists? (dir)
        g = Git.clone(rep_map[:origin][:uri], rep_map[:name], :path => rep_map[:working_dir])
        g.config('user.name', sync[:user_name])
        g.config('user.email', sync[:user_email])
    end
    cd dir
    #g = Git.open(working_dir, :log => Logger.new(STDOUT))
    g = Git.open(dir)
    #add remotes
    remotes = g.remotes.map { |r| r.to_s }
    rep_map[:destinations].each do |dest|
      if !remotes.include? dest[:remote]
        ap g.add_remote(dest[:remote], dest[:uri])
      end
    end
    #checkout remote branches from origin
    g.branches.remote.each do |branch|
         branch_fullname = branch.to_s
         m = /(remotes\/origin\/)([\w\-\_\.]*)/.match(branch_fullname)
         if m and m[2] != "HEAD"
           b = m[2]
           if !(g.branches.local.map {|b| b.to_s}).include?(b)
             ap g.reset_hard
             shell_execute("git checkout -b #{b} origin/#{b}")
           end
         end
      end
      #push to remote branches
      g.branches.local.each do |branch|
        g.reset_hard
        g.checkout(branch)
        g.reset_hard
        rep_map[:destinations].each do |dest|
          shell_execute("git checkout #{branch}")
          shell_execute("git push #{dest[:remote]} #{branch}")
        end
    end
  end #  sync.each do |rep_map|
  puts "Synchronizing again in 5 minutes"
  sleep(5*60)
end # while
