source "https://rubygems.org"
gemspec
gem "minitest"
gem "rake"

# This gem supports Ruby 3.2, and these two test tools need a newer Ruby:
# hegeltest 3.4, bulldogger 4.0. Gemfile.lock is not committed, so each Ruby
# resolves its own set, and the tests that need hegeltest skip without it.
group :test do
  gem "hegeltest", "0.2.0" if RUBY_VERSION >= "3.4"
  if RUBY_VERSION >= "4.0"
    gem "bulldogger", "0.3.1"
    gem "debug", "1.11.1"
  end
end
