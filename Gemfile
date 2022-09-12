source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.2"

gem "rails", "~> 7.0.4"
gem "sprockets-rails"
gem "pg", "~> 1.4"
gem "puma", "~> 5.0"
gem "jbuilder"
gem "sassc-rails"
gem "bootsnap", require: false
gem 'bootstrap'
gem 'bootstrap-icons-helper'

group :development, :test do
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
end

group :development do
  gem "web-console"
end

group :test do
  gem "rails-controller-testing"
end
