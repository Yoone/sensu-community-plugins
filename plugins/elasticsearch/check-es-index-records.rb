#! /usr/bin/env ruby
#
#   check-es-index-records
#
# DESCRIPTION:
#   This plugin checks the number of records in an ElasticSearch index, using its API.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#   gem: rest-client
#
# USAGE:
#   example commands
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class ESIndexRecords < Sensu::Plugin::Check::CLI
  option :host,
         description: 'ElasticSearch host',
         short: '-h HOST',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'ElasticSearch port',
         short: '-p PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 9200

  option :timeout,
         description: 'Sets the connection timeout for REST client',
         short: '-t SECS',
         long: '--timeout SECS',
         proc: proc(&:to_i),
         default: 30

  option :index,
         description: 'ElasticSearch index to query',
         short: '-i ES_INDEX',
         long: '--index ES_INDEX',
         required: true

  option :query,
         description: 'ElasticSearch query to execute',
         short: '-q ES_QUERY',
         long: '--query ES_QUERY',
         required: true

  option :critical,
         description: 'Critical maximum number of records',
         short: '-c MAX_RECORDS',
         proc: proc(&:to_i),
         required: true

  option :warning,
         description: 'Warning maximum number of records',
         short: '-w MAX_RECORDS',
         proc: proc(&:to_i),
         required: true

  def get_index_records()
    r = RestClient::Resource.new("http://#{config[:host]}:#{config[:port]}/#{config[:index]}/_search?ignore_unavailable=true", timeout: config[:timeout])
    JSON.parse(r.post config[:query])
  rescue Errno::ECONNREFUSED
    warning 'Connection refused'
  rescue RestClient::RequestTimeout
    warning 'Connection timed out'
  end

  def run
    begin
      info = get_index_records()
      records = info['hits']['total'].to_i
    rescue NoMethodError
      warning 'Failed to retrieve number of records'
    end

    if records >= config[:critical]
      critical "Found #{records} records in #{config[:index]} and it exceeds #{config[:critical]} (critical threshold)"
    elsif records >= config[:warning]
      warning "Found #{records} records in #{config[:index]} and it exceeds #{config[:warning]} (warning threshold)"
    else
      ok "Found #{records} records in #{config[:index]}"
    end
  end
end
