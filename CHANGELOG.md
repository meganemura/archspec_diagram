# Changelog

## [Unreleased]

- Property tests with hegeltest for label escaping and for the node and edge structure of a rendered diagram. They run on Ruby 3.4 and later and skip on older Rubies.
- On Ruby 4.0 the test suite loads bulldogger, so a failure writes its evidence to `tmp/bulldogger/`.
- Each property test stores its failing case under `.hegel/`, keyed by test name, so rerunning a failed test locally replays the same counterexample.
- CI also runs on pushes to the `queue` branch.

## [0.1.0]

First release. `archspec_diagram` draws an `Archspec.rb` as a Mermaid flowchart, in mermaid, markdown or html form.
