#! /usr/bin/env ruby
#
#   transferto-balance-check
#
# DESCRIPTION:
#   This plugin checks the account balance for TransferTo API (https://fm.transfer-to.com/shop/TransferTo_API.pdf).
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#   example commands
#
# NOTES:
#   Does it behave differently on specific platforms, specific use cases, etc
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'digest'
require 'net/https'
require 'uri'
require 'rexml/document'
require 'sensu-plugin/check/cli'

class TransferToBalanceCheck < Sensu::Plugin::Check::CLI
  option :warn,
         short: '-w BALANCE_THRESHOLD',
         long: '--warning-threshold BALANCE_THRESHOLD',
         description: 'TransferTo Warning Balance Threshold',
         required: true

  option :critical,
         short: '-c BALANCE_THRESHOLD',
         long: '--critical-threshold BALANCE_THRESHOLD',
         description: 'TransferTo Critical Balance Threshold',
         required: true

  option :accountLogin,
         short: '-a TRASNFERTO_ACCOUNT_LOGIN',
         long: '--account-login TRANSFERTO_ACCOUNT_LOGIN',
         description: 'TransferTo API Account Login',
         required: true

  option :accountToken,
         short: '-t TRANSFERTO_AUTH_TOKEN',
         long: '--auth-token TRANSFERTO_AUTH_TOKEN',
         description: 'TransferTo Auth Token',
         required: true

  def run
    uri = URI.parse("https://fm.transfer-to.com/cgi-bin/shop/topup")
    http = Net::HTTP.new(uri.host, uri.port)

    login = config[:accountLogin]
    token = config[:accountToken]

    key = Time.now.to_i.to_s
    md5 = Digest::MD5.hexdigest login + token + key

    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.request_uri, _initheader = { 'Content-Type' => 'text/xml' })
    request.body = "
    <xml>
      <login>#{login}</login>
      <key>#{key}</key>
      <md5>#{md5}</md5>
      <action>check_wallet</action>
    </xml>
    "
    responseData = http.request(request).body

    # extract event information
    doc = REXML::Document.new(responseData)
    balance = doc.elements["TransferTo/wallet"].text.to_f

    if balance < config[:critical].to_f
      critical "The TransferTo account balance is at #{balance}."
    elsif balance < config[:warn].to_f
      warning "The TransferTo account balance is at #{balance}."
    else
      ok "The TransferTo API account balance is at #{balance}."
    end
  end
end
