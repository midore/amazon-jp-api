#!/usr/local/bin/ruby
# coding: utf-8
# run-amazon-api.rb

# 2009-08-05

begin
  raise "sorry, only ruby 1.9.1" if RUBY_VERSION < "1.9.1"
  ext = Encoding.default_external.name
  raise "Error, LANG must be UTF-8" unless ext == 'UTF-8'
end

load 'config', wrap=true
require 'amazon'
$LOAD_PATH.delete(".")

require 'time'
require 'timeout'
require 'rexml/document'
require 'uri'
require 'net/http'

# edit this line use AmazonAPI
openid = '/path/to/ruby-openid-2.1.6/lib'
$LOAD_PATH.push(openid)
require 'openid'

def command(str, opt)
  return nil unless str
  return nil if str.size > 3
  case str
  when /^l$/ 
    AmazonAPI::AwsData.new().view(opt.to_i-1)
  when /^isbn$/
    AmazonAPI::AwsData.new().view_isbnlist
  else
    return nil unless opt
    AmazonAPI::AmazonAccess.new(opt).base if /^add$/ =~ str
    AmazonAPI::AwsData.new().lookup(opt) if /^s$/ =~ str
  end
end

arg = ARGV
w1, w2 = arg[0], arg[1]
command(w1, w2)

