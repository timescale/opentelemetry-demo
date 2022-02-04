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

Bundler.require

ENV['OTEL_TRACES_EXPORTER'] ||= 'otlp'
ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] ||= 'http://collector:4318'

OpenTelemetry::SDK.configure do |c|
   c.service_name = "lower"
   c.logger.level = Logger::DEBUG
   c.logger.debug("Using OTLP endpoint: #{ENV['OTEL_EXPORTER_OTLP_ENDPOINT']}")
   c.use_all
end


# Rack middleware to extract span context, create child span, and add
# attributes/events to the span
class OpenTelemetryMiddleware
  def initialize(app)
    @app = app
    @tracer = OpenTelemetry.tracer_provider.tracer('sinatra', '1.0')
  end

  def call(env)
    # Extract context from request headers
    context = OpenTelemetry.propagation.extract(
      env,
      getter: OpenTelemetry::Common::Propagation.rack_env_getter
    )

    status, headers, response_body = 200, {}, ''
    #OpenTelemetry.logger.debug("One more request #{env.inspect}")

    # Span name SHOULD be set to route:
    span_name = env['PATH_INFO']

    # For attribute naming, see
    # https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/data-semantic-conventions.md#http-server

    # Activate the extracted context
    OpenTelemetry::Context.with_current(context) do
      # Span kind MUST be `:server` for a HTTP server span
      @tracer.in_span(
        span_name,
        attributes: {
          'component' => 'http',
          'http.method' => env['REQUEST_METHOD'],
          'http.route' => env['PATH_INFO'],
          'http.url' => env['REQUEST_URI'],
        },
        kind: :server
      ) do |span|
        # Run application stack
        status, headers, response_body = @app.call(env)

        span.set_attribute('http.status_code', status)
      end
    end

    [status, headers, response_body]
  end
end


OpenTelemetry::Exporter::OTLP::Exporter.class_eval do
  def export(span_data, timeout: nil)
    return FAILURE if @shutdown
    OpenTelemetry.logger.debug("Sending #{span_data.size} (timeout: #{timeout}) elements in batch.")
    send_bytes(encode(span_data), timeout: timeout)
    OpenTelemetry.logger.debug("Done #{span_data.size} elements in batch.")
  end
end
module OpenTelemetry
  module SDK
    module Trace
      module Export
        class BatchSpanProcessor # rubocop:disable Metrics/ClassLength
          def report_result(result_code, batch)
            OpenTelemetry.logger.debug("#{result_code.zero? ? "Success" : "Fail"} to report #{batch.size} elements in batch.")
    #        super
          end
        end
      end
    end
  end
end

set :bind, '0.0.0.0'
set :port, 5000

use OpenTelemetryMiddleware
CHARS = ('a'..'z').to_a

get '/' do
  content_type :json
  c = CHARS.sample
=begin
  if ('q'..'z').include?(c)
    tracer = OpenTelemetry.tracer_provider.tracer('sinatra', '1.0')
    tracer.in_span("process_lower") do |span|
      span.set_attribute('char', c)
      #span.add_event("processing lower char", {'char': c})
      sleep(rand / 100.0)
      # 1/100 calls is extra slow
      if rand > 0.99
      #  span.add_event("extra work", {'char': c})
        sleep(rand / 100)
      end

      # these chars are extra slow
      if %w[z x r].include?(c)
        tracer.in_span("extra_process_lower") do |span|
          span.set_attribute('char', c)
          sleep(rand / 10)
        end
      end

      # these chars are extra slow too
      if %w[z u t].include?(c)
        tracer.in_span("extra_extra_process_lower") do |span|
          span.set_attribute('char', c)
          sleep(rand / 10)
        end
      end
      sleep rand
    end
  end
=end
  {char: c}.to_json
end
