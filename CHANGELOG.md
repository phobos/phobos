# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## UNRELEASED
### Added
- Support for outputting logs as json #50
- Make configuration, especially of listeners, more flexible. #31
- Phobos Discord chat

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
