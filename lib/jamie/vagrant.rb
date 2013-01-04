# -*- encoding: utf-8 -*-
#
# Author:: Fletcher Nichol (<fnichol@nichol.ca>)
#
# Copyright (C) 2012, Fletcher Nichol
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'forwardable'
require 'vagrant'

require 'jamie'

module Jamie

  module Vagrant

    # A Vagrant confiuration class which wraps a Jamie::Config instance.
    #
    # @author Fletcher Nichol <fnichol@nichol.ca>
    class Config < ::Vagrant::Config::Base
      extend Forwardable

      def_delegators :@config, :suites, :suites=, :platforms, :platforms=,
        :instances, :yaml_file, :yaml_file=, :log_level, :log_level=,
        :test_base_path, :test_base_path=, :yaml_data

      def initialize
        @config = Jamie::Config.new
        @config.yaml_file = ENV['JAMIE_YAML'] if ENV['JAMIE_YAML']
      end

      # Override default implementation to prevent serializing the config
      # instance variable, which may contain circular references.
      #
      # @return [Hash] an empty Hash
      def instance_variables_hash
        {}
      end
    end

    # Defines all Vagrant virtual machines, one for each instance.
    #
    # @param config [Vagrant::Config::Top] Vagrant top level config object
    def self.define_vms(config)
      config.jamie.instances.each do |instance|
        define_vagrant_vm(config, instance)
      end
    end

    private

    def self.define_vagrant_vm(config, instance)
      driver = instance.driver

      config.vm.define instance.name do |c|
        c.vm.box = driver['box']
        c.vm.box_url = driver['box_url'] if driver['box_url']
        c.vm.host_name = "#{instance.name}.vagrantup.com"

        driver['customize'].each do |key,value|
          c.vm.customize ["modifyvm", :id, "--#{key}", value]
        end

        c.vm.provision :chef_solo do |chef|
          chef.log_level = config.jamie.log_level
          chef.run_list = instance.run_list
          chef.json = instance.attributes
          chef.data_bags_path = instance.suite.data_bags_path
          chef.roles_path = instance.suite.roles_path
        end
      end
    end
  end
end

Vagrant.config_keys.register(:jamie) { Jamie::Vagrant::Config }
