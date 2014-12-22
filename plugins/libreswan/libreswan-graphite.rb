#!/usr/bin/env ruby
#
# Libreswan metrics using ipsec command
# ===
#
# DESCRIPTION:
#   This plugin uses libreswan's ipsec whack command w/ trafficstatus option to collect metrics
#   from an instance of libreswan running on the host the script is executed on.
#
# NOTES:
#   My understanding is that libreswan cannot be run as a standard user if we wish to modify
#   iptables rules in its ifup/down scripts (we need this). Because of this, the ctrl socket the
#   ipsec command uses becomes owned by root thus preventing any non-root user from launching
#   the ipsec command. We have hacked around this using a sudo rule granting permission
#   to the sensu user for the ipsec command.
#
# OUTPUT:
#   Graphite plain-text format (name value timestamp\n)
#
# PLATFORMS:
#   linux
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   ipsec whack --trafficstatus
#
# USAGE:
#
#   $ ./libreswan-graphite.rb
#   host.libreswan.connections 1 1419278260
#   host.libreswan.outbytes 7699 1419278260
#   host.libreswan.inbytes 13656 1419278260

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class LibreswanMetrics < Sensu::Plugin::Metric::CLI::Graphite

    option :scheme,
        :description => "Metric naming scheme, text to prepend to metric",
        :short => "-s SCHEME",
        :long => "--scheme SCHEME",
        :default => "#{Socket.gethostname}.libreswan"

    def extract_stats(stat)
        bytes = /.*inBytes=(?<inBytes>\d+).*outBytes=(?<outBytes>\d+).*/.match(stat)
        return bytes[:inBytes].to_i, bytes[:outBytes].to_i
    end

    def run
        timestamp = Time.now.to_i
        # 006 is RC_INFORMATIONAL_TRAFFIC
        conns = `sudo ipsec whack --trafficstatus`.lines.select { |stat| stat.start_with?("006") }
        connCount = conns.size
        inBytes = 0
        outBytes = 0
        if connCount > 0
            inBytes, outBytes = conns.map { |stat| extract_stats(stat) }.transpose.map { |x| x.reduce(:+) }
        end
        output "#{config[:scheme]}.connections", connCount, timestamp
        output "#{config[:scheme]}.outbytes", outBytes, timestamp
        output "#{config[:scheme]}.inbytes", inBytes, timestamp
        ok
    end
end