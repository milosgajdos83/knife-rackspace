#
# Author:: Milos Gajdos (<milos@gocardless.com>)
# Copyright:: Copyright (c) 2013 GoCardless, Ltd.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife'
require 'chef/knife/rackspace_loadbalancer_base'
require 'chef/knife/rackspace_loadbalancer_nodes'
require 'fog'

module RackspaceService
  class RackspaceLoadbalancerCreate < Chef::Knife
  	include Chef::Knife::RackspaceLoadBalancerBase
    include Chef::Knife::RackspaceLoadBalancerNodes

    banner "knife rackspace loadbalancer create NAME (options)"

    option :force,
      :long => "--force",
      :description => "Skip user input"

    option :protocol,
      :long => "--protocol PROTOCOL",
      :description => "The protocol to balance [Default: HTTP]",
      :default => "HTTP"

    option :lb_port,
      :long => "--lb-port PORT",
      :description => "This is necessary to be specified only for UDP/TCP ports",
      :default => 80

    option :virtual_ip_type,
      :long => "--virtual-ip-type TYPE",
      :description => "Type of virtual IP to obtain - SERVICENET or PUBLIC [DEFAULT: SERVICENET]",
      :default => "SERVICENET"

    option :add_nodes_by_search,
      :long => "--add-nodes-by-search SEARCH",
      :description => "Node search query resolved by Chef Server to add"

    option :add_nodes_by_private_ip,
      :long => "--add-nodes-by-private-ip \"IP[,IP]\"",
      :description => "Comma deliminated list of private ips to add"

    option :add_nodes_by_name,
      :long => "--add-nodes-by-name \"NAME[,NAME]\"",
      :description => "Comma deliminated list of node names resolved by Chef Server to add"

    option :node_port,
      :long => "--node-port PORT",
      :description => "Add nodes listening to this port DEFAULT: 80",
      :default => "80"

    option :node_condition,
      :long => "--node-condition CONDITION",
      :description => "Add nodes with this condition. Handy for JUST creating a load balancer",
      :default => "ENABLED"

    option :algorithm,
      :long => "--algorithm ALGORITHM",
      :description => "The algorithm to employ for load balancing [Defualt: ROUND_ROBIN]",
      :default => "ROUND_ROBIN"

    option :connection_logging,
      :long => "--connection_logging",
      :description => "Enable connection logging [DEFAULT: FALSE]",
      :boolean => true | false,
      :default => false

    def run
      unless name_args.size == 1
        ui.fatal("You must provide Load Balancer name !")
        show_usage
        exit 1
      end

      # we need to check if at least some nodes have been specified
      # as you can't create LB with empty host pool
      unless (config.keys & [:add_nodes_by_search, :add_nodes_by_private_ip, :add_nodes_by_name]).any?
        ui.fatal("Must specify list of nodes. Load Balancer can't be created with empty host pool!")
        ui.fatal("Must provide nodes via --add-nodes-by-search, --add-nodes-by-private-ip, or --add-nodes-by-name\n")
        show_usage
        exit 2
      end
      
      unless config[:force]
        ui.confirm("Do you really want to create this load balancer ")
      end

      node_ips = get_node_ips({
        :by_search     => config[:add_nodes_by_search],
        :by_name       => config[:add_nodes_by_name],
        :by_private_ip => config[:add_nodes_by_private_ip]
      })

      nodes = node_ips.map do |ip|
        {
          :address => ip,
          :port => config[:node_port],
          :condition => config[:node_condition]
        }
      end

      vip_types = config[:virtual_ip_type].split(",")
      vips = vip_types.map do |vip|
        {
           "type" => vip
        }
      end

      loadbalancer_name = name_args.first
      options = { :algorithm => config[:algorithm], 
        :connection_logging => config[:connection_logging]}

      # TODO:
      loadbalancer = connection.create_load_balancer(loadbalancer_name, config[:protocol],
        config[:lb_port], vips, nodes, options)

      loadbalancer_id = loadbalancer.body["loadBalancer"]["id"]

      ui.output(ui.color("Created load balancer #{loadbalancer_name}.Load Balancer ID: #{loadbalancer_id}", :green, :bold))

    end
  end
end