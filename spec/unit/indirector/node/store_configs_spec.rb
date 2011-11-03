#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/node'
require 'puppet/indirector/node/store_configs'
require 'puppet/indirector/memory'

class Puppet::Node::StoreConfigsTesting < Puppet::Indirector::Memory
end

describe Puppet::Node::StoreConfigs do
  after :each do
    Puppet::Node.indirection.reset_terminus_class
    Puppet::Node.indirection.cache_class = nil
  end

  it_should_behave_like "a StoreConfigs terminus"
end
