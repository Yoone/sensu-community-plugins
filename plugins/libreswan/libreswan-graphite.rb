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
#   host.libreswan.outmb 76.99 1419278260
#   host.libreswan.inmb 136.56 1419278260
#   host.libreswan.memusage 600.97 1419278260

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class LibreswanMetrics < Sensu::Plugin::Metric::CLI::Graphite

    option :scheme,
        :description => "Metric naming scheme, text to prepend to metric",
        :short => "-s SCHEME",
        :long => "--scheme SCHEME",
        :default => "#{Socket.gethostname}.libreswan"

    def toMB(bytes)
        return bytes / 1048576.0
    end

    def extractStats(stat)
        bytes = /.*inBytes=(?<inBytes>\d+).*outBytes=(?<outBytes>\d+).*/.match(stat)
        return toMB(bytes[:inBytes].to_f),toMB(bytes[:outBytes].to_f)
    end

    def memUsage
        pid = `pidof pluto`.strip
        unless pid == ""
            File.foreach("/proc/#{pid}/status") { |x|
                if x.start_with?("VmSize")
                    return x.split()[1].to_f / 1024
                end
            }
        end
        return 0
    end

    def run
        timestamp = Time.now.to_i
        # 006 is RC_INFORMATIONAL_TRAFFIC
        conns = `sudo ipsec whack --trafficstatus`.lines.select { |stat| stat.start_with?("006") }
        connCount = conns.size
        inMB = 0.0
        outMB = 0.0
        if connCount > 0
            inMB, outMB = conns.map { |stat| extractStats(stat) }.transpose.map { |x| x.reduce(:+) }
        end
        output "#{config[:scheme]}.connections", connCount, timestamp
        output "#{config[:scheme]}.outmb", "%.2f" % outMB, timestamp
        output "#{config[:scheme]}.inmb", "%.2f" % inMB, timestamp
        output "#{config[:scheme]}.memusage", "%.2f" % memUsage, timestamp
        ok
    end
end