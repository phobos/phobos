FROM ruby:2.5.1-alpine

RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh build-base
RUN gem install bundler -v 1.16.1

WORKDIR /opt/phobos

ADD Gemfile Gemfile
ADD phobos.gemspec phobos.gemspec
ADD lib/phobos/version.rb lib/phobos/version.rb
RUN bundle install

ADD . .
