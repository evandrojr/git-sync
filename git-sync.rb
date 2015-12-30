#!/usr/bin/env ruby

require 'git'
require 'awesome_print'
require 'yaml'
require 'airbrake'
# require 'pry-byebug'

include FileUtils

config =  YAML.load(File.read(File.join(__dir__,'sync.yaml')))

Airbrake.configure do |config|
  config.api_key = '43ed39d3148d60187e8be4a1715350e4'
  config.host    = 'diagnostico.participa.br'
  config.port    = 80
  config.secure  = config.port == 443
end

def shell_execute(command, options = {})
  silent = options.fetch(:silent, false)
  raise_error = options.fetch(:raise_error, false)
  puts command unless silent
  o = `#{command}`
  r = $?.to_i
  if r!=0
    error_msg = "Error: #{o} Code: #{r} Command: #{command}"
    puts error_msg
    raise error_msg if raise_error
  end
  r
end

def error_hander(error)
  puts error
  Airbrake.notify_or_ignore(
    error
  )
end

def run(sync)

  sync[:maps].each do |rep_map|
    puts "+++++++++++ Synchronizing mapping +++++++++++"
    puts rep_map.to_yaml
    puts "+++++++++++++++++++++++++++++++++++++++++++++"

    rep_map[:working_dir] = File.expand_path(rep_map[:working_dir])
    dir = "#{rep_map[:working_dir]}/#{rep_map[:name]}"

    if !Dir.exists? (dir)
        puts "Cloning from #{rep_map[:origin][:uri]}"
        g = Git.clone(rep_map[:origin][:uri], rep_map[:name], :path => rep_map[:working_dir])
        g.config('user.name', sync[:user_name])
        g.config('user.email', sync[:user_email])
    end
    cd dir
    # g = Git.open(working_dir, :log => Logger.new(STDOUT))
    g = Git.open(dir)
    # add remotes
    remotes = g.remotes.map { |r| r.to_s }
    rep_map[:destinations].each do |dest|
      #Avoid putshes to "@softwarepublico.gov.br" by mistake
      if dest[:uri].include?("softwarepublico.gov.br")
        raise "You should not push to softwarepublico.gov.br"
        exit 1
      end
      if !remotes.include? dest[:remote]
        puts "Adding remote: #{dest[:remote]} into #{dest[:uri]}"
        g.add_remote(dest[:remote], dest[:uri], raise_error: true)
      end
    end


    # checkout remote branches from origin
    g.branches.remote.each do |branch|
      branch_fullname = branch.to_s
      m = /(remotes\/origin\/)(.+$)/.match(branch_fullname)
      if m and !(branch.name =~ /^HEAD/)
       if !((g.branches.local.map {|b| b.to_s }).include?(branch.name))
         g.reset_hard
         shell_execute("git checkout -b #{branch.name} origin/#{branch.name}", raise_error: true)
       else
         g.reset_hard
         shell_execute("git checkout #{branch.name}", raise_error: true)
         shell_execute("git pull", silent: true)
       end
      end
    end
    # push to remote branches
    g.branches.local.each do |branch|
      g.reset_hard
      g.checkout(branch)
      g.reset_hard
      rep_map[:destinations].each do |dest|
        begin
          shell_execute("git push #{dest[:remote]} #{branch}  ", raise_error: true)
        rescue=>error
          error_hander(error)
        end
      end
    end
  end # sync[:maps].each do |rep_map|

end

########## Begining of the execution flow #############

shell_execute('git config --global url."https://".insteadOf git://', silent: true)

while true
  begin
    run config
    puts "Synchronizing again in 5 minutes"
    sleep(5*60)
  rescue=>error
    error_hander(error)
  end
end
