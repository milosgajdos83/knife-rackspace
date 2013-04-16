require 'chef/knife'
require 'chef/knife/rackspace_loadbalancer_base'
require 'chef/knife/rackspace_loadbalancer_nodes'
require 'fog'

module KnifePlugins
  class RackspaceLoadbalancerAddNode < Chef::Knife
    include Chef::Knife::RackspaceLoadBalancerBase
    include Chef::Knife::RackspaceLoadBalancerNodes
    include Chef::Knife::RackspaceLoadbalancerShow

    banner "knife rackspace loadbalancer add node LB-ID (options)"

    option :force,
      :long => "--force",
      :description => "Skip user input"

    option :port,
      :long => "--port PORT",
      :description => "Add node listening to this port [DEFAULT: 80]",
      :default => "80"

    option :condition,
      :long => "--condition CONDITION",
      :description => "Add node in this condition [DEFAULT: ENABLED]",
      :default => "ENABLED"

    option :weight,
      :long => "--weight WEIGHT",
      :description => "Add node with this weight [DEFAULT: 1]",
      :default => "1"

    option :type,
      :long => "--type TYPE",
      :description => "Add node with this type [DEFAULT: PRIMARY]",
      :default => "PRIMARY"    

    option :add_nodes_by_name,
      :long => "--add-nodes-by-name \"NAME[,NAME]\"",
      :description => "Resolve names against chef server to produce list of nodes to add"

    option :add_nodes_by_private_ip,
      :long => "--add-nodes-by-private-ip \"IP[,IP]\"",
      :description => "List of nodes given by private ips to add"

    option :add_nodes_by_search,
      :long => "--add-nodes-by-search SEARCH",
      :description => "Resolve search against chef server to produce list of nodes to add"

    option :auto_resolve_port,
      :long => "--auto-resolve-port",
      :description => "Auto resolve port of node addition"
      :boolean => true | false,
      :default => false

    def run
      unless name_args.size == 1
        ui.fatal("You must provide Load Balancer ID!")
        show_usage
        exit 1
      else
        lb_id = name_args.first
      end

      # we need to check if at least some nodes have been specified
      unless (config.keys & [:add_nodes_by_search, :add_nodes_by_private_ip, :add_nodes_by_name]).any?
        ui.fatal("Must specify list of nodes. Load Balancer can't be created with empty host pool!")
        ui.fatal("Must provide nodes via --add-nodes-by-search, --add-nodes-by-private-ip, or --add-nodes-by-name\n")
        show_usage
        exit 2
      end

      unless node_ips.empty?
        ui.fatal("No Chef Nodes found!")
        ui.fatal("Specified nodes must be registered with following Chef Server: #{Chef::Config[:chef_server_url]}")
        exit 2
      else
        node_ips = get_node_ips({
          :by_search     => config[:add_nodes_by_search],
          :by_name       => config[:add_nodes_by_name],
          :by_private_ip => config[:add_nodes_by_private_ip]
        })
      end

      loadbalancer = connection.get_load_balancer(lb_id).body["loadBalancer"]
      loadbalancer_port  = loadbalancer["port"]
      loadbalancer_nodes = loadbalancer["nodes"]

      nodes = node_ips.map do |ip|
        {
          :address => ip,
          :port =>  config[:auto_resolve_port] ? loadbalancer_port : config[:port],
          :condition => config[:condition],
          :weight => config[:weight],
          :type => config[:type]
        }
      end

      # current Load Balancer pool
      lb_pool = loadbalancer_nodes.map { |n| n[:address] }
      new_nodes = nodes.reject { |n| lb_pool.include?(n[:address]) }

      new_nodes.each do |node|
        ui.output("Adding #{node[:address]} to #{loadbalancer["name"]} (#{loadbalancer["id"]})...")
        node = connection.create_node(lb_id, node[:address], node[:port], node[:condition],
          "weight" => node[:weight], "condition" => node[:condition])
      end

      ui.output(ui.color("#{new_nodes.size} have been added to #{loadbalancer["name"]} Load Balancer", :green))

    end
  end
end
