# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

task default: %i[style test build]

RSpec::Core::RakeTask.new(:test)

RuboCop::RakeTask.new(:style) do |task|
  task.requires << 'rubocop-rake'
end
