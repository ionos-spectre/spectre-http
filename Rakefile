# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rubocop/rake_task'
require 'rdoc/task'
require 'rspec/core/rake_task'

task default: %i[style test doc build]

RuboCop::RakeTask.new(:style) do |task|
  task.requires << 'rubocop-rake'
end

RSpec::Core::RakeTask.new(:test)

RDoc::Task.new(:doc) do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.rdoc_files.include('lib/**/*.rb')
end
