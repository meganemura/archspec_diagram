# sig/generated is written by `bundle exec rbs-inline --output=sig/generated lib`
# from the comments in lib/. Run `bundle exec steep check` after a change to lib/.
# sig-deps holds what lib/ calls of archspec, which ships no signatures; the
# gem ships sig/ only.
target :lib do
  signature "sig", "sig-deps"
  check "lib"
  library "optparse", "cgi", "pathname"
end
