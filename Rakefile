require "foodcritic"
require "rspec/core/rake_task"

task :default => [ :foodcritic, :spec, "kitchen:all" ]
FoodCritic::Rake::LintTask.new
RSpec::Core::RakeTask.new(:spec) do |task|
	task.rspec_opts = "--color test/spec"
end

begin
  require 'kitchen/rake_tasks'
  Kitchen::RakeTasks.new
rescue LoadError
  puts ">>>>> Kitchen gem not loaded, omitting tasks" unless ENV['CI']
end
