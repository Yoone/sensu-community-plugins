#!/usr/bin/env ruby
#
# Checks Mandrill Email Delivery Stats
# ===
#
# DESCRIPTION:
#   This plugin pulls info from mandrill (transactional email) and outputs email delivery statistics for each time period & the user's current reputation and backlog size
#
# OUTPUT:
#   graphite
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'net/https'
require 'uri'
require 'json'

class MandrillInfo < Sensu::Plugin::Metric::CLI::Graphite

  option :authToken,
    :short => '-t MANDRILL_AUTH_TOKEN',
    :long => '--auth-token MANDRILL_AUTH_TOKEN',
    :description => 'Mandrill Auth Token',
    :required => true

  def run
    uri = URI("https://mandrillapp.com/api/1.0/users/info.json")
    req = Net::HTTP::Post.new uri.path

    req.body = {:key => config[:authToken]}.to_json

    res = Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.ssl_version = :SSLv3
      http.request req
    end

    json = JSON.parse res.body
    all_stats = json["stats"]

    all_stats.each { |time_period, stats| output_stats(time_period, stats) }

    output "mandrill.stats.reputation", json["reputation"]
    output "mandrill.stats.backlog", json["backlog"]
    ok
  end

  def output_stats(time_period, stats)
      output "mandrill.stats.#{time_period}.sent", stats["sent"]
      output "mandrill.stats.#{time_period}.unsubs", stats["unsubs"]
      output "mandrill.stats.#{time_period}.rejects", stats["rejects"]
      output "mandrill.stats.#{time_period}.complaints", stats["complaints"]
      output "mandrill.stats.#{time_period}.opens", stats["opens"]
  end

end
