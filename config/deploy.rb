# config valid for current version and patch releases of Capistrano
lock "~> 3.11.2"

set :application, "discord-recruitment-bot"
set :repo_url, "https://github.com/utyosu/discord-recruitment-bot"
set :branch, ENV['BRANCH'] || "master"

set :bundle_jobs, 1

set :puma_threads,    [4, 16]
set :puma_workers,    0
set :pty,             true
set :use_sudo,        false
set :deploy_via,      :remote_cache
set :deploy_to,       "/home/ops/#{fetch(:application)}"
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.error.log"
set :puma_error_log,  "#{release_path}/log/puma.access.log"
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true

set :linked_dirs, fetch(:linked_dirs, []).push(
  'log',
  'tmp/pids',
  'tmp/cache',
  'tmp/sockets',
  'vendor/bundle',
  'public/system',
  'public/uploads'
)
namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
    end
  end
  before :start, :make_dirs
end

namespace :deploy do
  task :compile_assets do
    on roles(:app) do
      execute "cd #{release_path} && RAILS_ENV=#{fetch :rails_env} bundle exec rails assets:precompile"
    end
  end
  after  :finishing, :compile_assets

  task :migrate_with_ridgepole do
    on roles(:app) do
      execute "cd #{release_path} && bundle exec ridgepole -c config/database.yml --apply -f db/schema -E #{fetch :rails_env}"
    end
  end
  after :migrate, :migrate_with_ridgepole
end

namespace :bot do
  task :start do
    on roles(:app) do
      execute "cd #{release_path} && RAILS_ENV=#{fetch :rails_env} bundle exec ruby bin/discord/bot.rb start"
    end
  end

  task :stop do
    on roles(:app) do
      execute "cd #{release_path} && RAILS_ENV=#{fetch :rails_env} bundle exec ruby bin/discord/bot.rb stop"
    end
  end

  task :restart do
    on roles(:app) do
      execute "cd #{release_path} && RAILS_ENV=#{fetch :rails_env} bundle exec ruby bin/discord/bot.rb restart"
    end
  end
end

after 'deploy:publishing', 'bot:restart'
