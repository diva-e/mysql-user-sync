require 'rspec/core/rake_task'
require 'rubocop/rake_task'

task default: [:rubocop, :spec]

task(:spec) do
  RSpec::Core::RakeTask.new(:spec)
end

desc 'Run rubocop'
task :rubocop do
  RuboCop::RakeTask.new(:rubocop) do |task|
    # task.patterns = ['lib/**/*.rb']
    # only show the files with failures
    # task.formatters = ['files']
    # don't abort rake on failure
    task.fail_on_error = true

    task.options = ['--config', '.rubocop.yaml']
  end
end
