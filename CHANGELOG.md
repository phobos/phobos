# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).
``
## UNRELEASED

## [3.0.4] - 2022-05-30

- catch no method exception thrown from ruby-kafka with hash message

## [3.0.3] - 2022-02-07

- catch no method exception thrown from ruby-kafka

## [3.0.2] - 2022-01-26

- fix consumer crash problems

## [3.0.1] - 2022-01-25

- fix consumer crash problems

## [3.0.0] - 2021-12-29

- Added multiple clusters support for producers.

- Support configurable producer config key for producers

## [2.1.0] - 2021-05-27

- Modify config to allow specifying kafka connection information separately for consumers and producers

## [2.0.2] - 2021-01-28
- Additional fixes for Ruby 3.0

## [2.0.1] - 2021-01-14
- Fix bug with Ruby 3.0 around OpenStruct

## [2.0.0-beta1] - 2020-05-04

- Remove deprecated patterns:
-- `before_consume` method
-- `around_consume` as a class method or without yielding values
-- `publish` and `async_publish` with positional arguments

## [1.9.0] - 2020-03-05
- Bumped version to 1.9.0.

## [1.9.0-beta3] - 2020-02-05

- Fix bug where deprecation errors would be shown when receiving nil payloads
  even if `around_consume` was updated to yield them.


## [1.9.0-beta2] - 2020-01-09

- Allow `around_consume` to yield payload and metadata, and deprecate
  `before_consume` and `around_consume` that does not yield anything.

## [1.9.0-beta1] - 2019-12-18
- Update `publish` and `async_publish` to use keyword arguments
  instead of positional ones. Deprecate positional arguments
  in anticipation of removing them with 2.0.

## [1.8.3-beta2] - 2019-11-15
- Add support for message headers in both produced and consumed
  messages and batches.

## [1.8.3-beta1] - 2019-11-11
- Automatically heartbeat after every message if necessary in batch
  mode.

## [1.8.2] - 2019-11-11
- Version bump for official release.

## [1.8.2-beta2] - 2019-06-21
- Added the `persistent_connections` setting and the corresponding
  `sync_producer_shutdown` method to enable reusing the connection
  for regular (sync) producers.

## [1.8.2-beta1] - 2019-03-13

- Added `BatchHandler` to consume messages in batches on the business
  layer.

## [1.8.1] - 2018-11-23
### Added
- Added ability to send partition keys separate from messsage keys.

## [1.8.0] - 2018-07-22
### Added
- Possibility to configure a custom logger #81
### Changed
- Reduce the volume of info-level log messages #78
- Phobos Handler `around_consume` is now an instance method #82
- Send consumer heartbeats between retry attempts #83

## [1.7.2] - 2018-05-03
### Added
- Add ability to override session_timeout, heartbeat_interval, offset_retention_time, offset_commit_interval, and offset_commit_threshold per listener
### Changed
- Phobos CLI: Load boot file before configuring (instead of after)

## [1.7.1] - 2018-02-22
### Fixed
- Phobos overwrites ENV['RAILS_ENV'] with incorrect value #71
- Possible NoMethodError #force_encoding #63
- Phobos fails silently #66
### Added
- Add offset_retention_time to consumer options #62

## [1.7.0] - 2017-12-05
### Fixed
- Test are failing with ruby-kafka 0.5.0 #48
- Allow Phobos to run in apps using ActiveSupport 3.x #57
### Added
- Property (handler) added to listener instrumentation #60
### Removed
- Property (time_elapsed) removed - use duration instead #24
### Changed
- Max bytes per partition is now 1 MB by default #56

## [1.6.1] - 2017-11-16
### Fixed
- `Phobos::Test::Helper` is broken #53

## [1.6.0] - 2017-11-16
### Added
- Support for outputting logs as json #50
- Make configuration, especially of listeners, more flexible. #31
- Phobos Discord chat
- Support for consuming `each_message` instead of `each_batch` via the delivery listener option. #21
- Instantiate a single handler class instance and use that both for `consume` and `before_consume`. #47

### Changed
- Pin ruby-kafka version to < 0.5.0 #48
- Update changelog to follow the [Keep a Changelog](http://keepachangelog.com/) structure

## [1.5.0] - 2017-10-25
### Added
- Add `before_consume` callback to support single point of decoding a message klarna/phobos_db_checkpoint#34
- Add `Phobos::Test::Helper` for testing, to test consumers with minimal setup required

### Changed
- Allow configuration of backoff per listener #35
- Move container orchestration into docker-compose
- Update docker images #38

### Fixed
- Make specs run locally #36

## [1.4.2] - 2017-09-29
### Fixed
- Async publishing always delivers messages #33

## [1.4.1] - 2017-08-22
### Added
- Update dev dependencies to fix warnings for the new unified Integer class

### Fixed
- Include the error `Kafka::ProcessingError` into the abort block

## [1.4.0] - 2017-08-21
### Added
- Support for hash provided settings #30

## [1.3.0] - 2017-06-15
### Added
- Support for ERB syntax in Phobos config file #26

## [1.2.1] - 2016-10-12
### Fixed
- Ensure JSON layout for log files

## [1.2.0] - 2016-10-10
### Added
- Log file can be disabled #20
- Property (time_elapsed) available for notifications `listener.process_message` and `listener.process_batch` #24
- Option to configure ruby-kafka logger #23

## [1.1.0] - 2016-09-02
### Added
- Removed Hashie as a dependency #12
- Allow configuring consumers min_bytes & max_wait_time #15
- Allow configuring producers max_queue_size, delivery_threshold & delivery_interval #16
- Allow configuring force_encoding for message payload #18

## [1.0.0] - 2016-08-08
### Added
- Published on Github!
