#!/usr/bin/env ruby
require 'git'
require 'awesome_print'
require 'yaml'
require 'airbrake'
require 'jazz_fingers'

include FileUtils
config = YAML.load(File.read(File.join(__dir__, 'sync.yml')))

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
  r = $CHILD_STATUS.to_i
  if r != 0
    error_msg = "Error: #{o} Code: #{r} Command: #{command}"
    puts error_msg
    fail error_msg if raise_error
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
    puts '+++++++++++ Synchronizing mapping +++++++++++'
    puts rep_map.to_yaml
    puts '+++++++++++++++++++++++++++++++++++++++++++++'

    rep_map[:working_dir] = File.expand_path(rep_map[:working_dir])
    dir = "#{rep_map[:working_dir]}/#{rep_map[:name]}"

    unless Dir.exist?(dir)
      puts "Cloning from #{rep_map[:origin][:uri]}"
      g = Git.clone(rep_map[:origin][:uri], rep_map[:name], path: rep_map[:working_dir])
      g.config('user.name', sync[:user_name])
      g.config('user.email', sync[:user_email])
    end
    cd dir
    # g = Git.open(working_dir, :log => Logger.new(STDOUT))
    g = Git.open(dir)

    puts "Fetching origin of #{rep_map[:name]}"
    g.remote('origin').fetch

    # add remotes
    rep_map[:destinations].each do |dest|
      # Avoid pushes to "@softwarepublico.gov.br" by mistake
      if dest[:uri].include?('softwarepublico.gov.br')
        fail 'You MUST NEVER push to softwarepublico.gov.br'
        exit 1
      end
      unless g.remotes.to_s.include? dest[:remote]
        puts "Adding remote: #{dest[:remote]} into #{dest[:uri]}"
        g.add_remote(dest[:remote], dest[:uri], raise_error: true)
      end
    end

    # Important to avoid a checkout from being blocked
    shell_execute('git reset --hard', raise_error: true)
    # checkout remote branches from origin
    g.branches.remote.each do |branch|
      branch_fullname = branch.to_s
      m = %r{(remotes/origin/)(.+$)}.match(branch_fullname)
      next unless m && !(branch.name =~ /^HEAD/)
      unless (g.branches.local.map(&:to_s)).include?(branch.name)
        shell_execute("git checkout -b #{branch.name} origin/#{branch.name}", raise_error: true)
              end
    end
    # push to remote branches
    g.branches.local.each do |branch|
      g.checkout(branch)
      rep_map[:destinations].each do |dest|
        begin
          shell_execute("git reset --hard origin/#{branch}", raise_error: true)
          shell_execute("git push -f #{dest[:remote]} #{branch}", raise_error: true)
        rescue => error
          error_hander(error)
        end
      end
    end
  end # sync[:maps].each do |rep_map|
end

########## Begining of the execution flow #############

shell_execute('git config --global url."https://".insteadOf git://', silent: true)

loop do
  begin
    run config
    puts 'Synchronizing again in 5 minutes'
    sleep(5 * 60)
  rescue => error
    error_hander(error)
  end
end
