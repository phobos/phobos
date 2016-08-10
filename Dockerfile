FROM ruby:2.3.1-alpine

RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh build-base

WORKDIR /opt/phobos

ADD Gemfile Gemfile
ADD phobos.gemspec phobos.gemspec
ADD lib/phobos/version.rb lib/phobos/version.rb

RUN ["bundle", "install"]
ADD . .
