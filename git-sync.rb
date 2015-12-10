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

# Shell execute
def shell_execute(command)
    puts command
    o = `#{command}`
    r = $?.to_i
    if r!=0
      puts "Error: #{o} code :#{r}"
    end
    r
end


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


    rep_map[:destinations].each do |dest|
      if !remotes.include? dest[:remote]
        ap g.add_remote(dest[:remote], dest[:uri])  # Git::Remote
      end
    end

  #checkout remote branches from origin
   g.branches.remote.each do |branch|
       branch_fullname = branch.to_s
       puts branch_fullname
       m = /(remotes\/origin\/)([\w|\-|\_]*)/.match("branch_fullname")
       if m
         b = m[2]
         shell_execute("git checkout -b #{b} origin/#{b}")
       end
    end
    #rep_map[:branches].each do |branch|
    g.branches.local.each do |branch|
      ap g.reset_hard
      ap g.checkout(branch)
      ap g.pull('origin')
      rep_map[:destinations].each do |dest|
        ap g.push(g.remote(dest[:remote]))
      end
    end
  end #  sync.each do |rep_map|
  puts "Trying again in 5 minutes"
  sleep(5*60)

end # while
