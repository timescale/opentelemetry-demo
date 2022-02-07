#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0
require 'rubygems'
require 'bundler/setup'
require 'faraday'
require 'opentelemetry/sdk'
require 'sinatra/base'
require 'json'
require 'net/http'

Bundler.require

ENV['OTEL_TRACES_EXPORTER'] ||= 'otlp'
ENV['OTEL_PROPAGATORS'] ||= 'tracecontext,baggage,b3'
ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] ||= 'http://collector:4318'

OpenTelemetry::SDK.configure do |c|
   c.service_name = "lower"
   c.logger.level = Logger::DEBUG
   c.logger.debug("Using OTLP endpoint: #{ENV['OTEL_EXPORTER_OTLP_ENDPOINT']}")
   c.use 'OpenTelemetry::Instrumentation::Sinatra'
   c.use 'OpenTelemetry::Instrumentation::Net::HTTP'
end

def sinatra_tracer
  OpenTelemetry.tracer_provider.tracer('sinatra', '1.0')
end

#use OpenTelemetryMiddleware
CHARS = ('a'..'z').to_a
def work time, span_name, c
  sinatra_tracer.in_span(span_name, attributes: { "char" => c}, kind: :server) do |span|
    sleep time
  end
end

def get_digit(c)
  sinatra_tracer.in_span("digit", attributes: { "char" => c}, kind: :client) do |span|
    begin
      digit = Net::HTTP.get(URI("http://digit:5000"))
      json = JSON.parse(digit)
      json['char']
    rescue Error => e
      span.record_exception(e)
      span.status = OpenTelemetry::Trace::Status.error
    end
  end
end

def prepare_char
  c = CHARS.sample
  get_digit(c)
  case c
  when 'z', 'x', 'r'
    work(0.05, 'extra_process_lower',  c)
  when 'z', 'a', 't'
    work(0.01, 'extra_extra_process_lower',  c)
  end
  c
end

set :bind, '0.0.0.0'
set :port, 5000

get '/' do
  content_type :json

  c = prepare_char

  {char: c}.to_json
end
