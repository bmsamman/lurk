#!/usr/bin/env ruby
require 'rubygems'
require 'trollop'
require 'fileutils'
load File.join(File.dirname(__FILE__), '..','lib','lurker.rb')
load File.join(File.dirname(__FILE__), '..','lib','lurk','lurk_command_helper.rb')
include LurkCommandHelper
run_lurk
