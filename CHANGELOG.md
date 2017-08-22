# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## 1.4.1 (2017-08-22)

- [enhancement] Update dev dependencies to fix warnings for the new unified Integer class
- [bugfix] Include the error `Kafka::ProcessingError` into the abort block

## 1.4.0 (2017-08-21)

- [enhancement] Add support for hash provided settings #30

## 1.3.0 (2017-06-15)

- [enhancement] Add support for erb syntax in phobos config file #26

## 1.2.1 (2016-10-12)

- [bugfix] Ensure JSON layout for log files

## 1.2.0 (2016-10-10)

- [enhancement] Log file can be disabled #20
- [enhancement] Add a new extra (time_elapsed) for notifications "listener.process_message" and "listener.process_batch" #24
- [enhancement] Add option to configure ruby-kafka logger #23

## 1.1.0 (2016-09-02)

- [enhancement] Removed Hashie as a dependency #12
- [feature] Allow configuring consumers min_bytes & max_wait_time #15
- [feature] Allow configuring producers max_queue_size, delivery_threshold & delivery_interval #16
- [feature] Allow configuring force_encoding for message payload #18

## 1.0.0 (2016-08-08)

- Published on Github with full fledged consumers and producers
