FROM ruby:2.7.3-alpine

RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh build-base
RUN gem install bundler

WORKDIR /opt/phobos

ADD Gemfile Gemfile
ADD phobos.gemspec phobos.gemspec
ADD lib/phobos/version.rb lib/phobos/version.rb
RUN bundle install

ADD . .
