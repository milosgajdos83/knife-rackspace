require 'chef/knife'
require 'chef/knife/rackspace_loadbalancer_base'
require 'chef/knife/rackspace_loadbalancer_nodes'
require 'fog'

module RackspaceService
  class RackspaceLoadbalancerAddNode < Chef::Knife
        include Chef::Knife::RackspaceLoadBalancerBase
    include Chef::Knife::RackspaceLoadBalancerNodes

    banner "knife rackspace loadbalancer add node (options)"

    option :force,
      :long => "--force",
      :description => "Skip user input"

    option :lb_id,
      :long => "--loadbalancer-id ID",
      :description => "Load Balancer ID"

    option :node_port,
      :long => "--node-port PORT",
      :description => "Add node listening on this port [DEFAULT: 80]",
      :default => "80"

    option :node_condition,
      :long => "--node-condition CONDITION",
      :description => "Add node in this condition [DEFAULT: ENABLED]",
      :default => "ENABLED"

    option :weight,
      :long => "--weight WEIGHT",
      :description => "Add node with this weight [DEFAULT: 1]",
      :default => "1"

    option :by_name,
      :long => "--by-name \"NAME[,NAME]\"",
      :description => "Resolve names against chef server to produce list of nodes to add"

    option :by_private_ip,
      :long => "--by-private-ip \"IP[,IP]\"",
      :description => "List of nodes given by private ips to add"

    option :by_search,
      :long => "--by-search SEARCH",
      :description => "Resolve search against chef server to produce list of nodes to add"

    option :auto_resolve_port,
      :long => "--auto-resolve-port",
      :description => "Auto resolve port of node addition"
      :boolean => true | false,
      :default => false

    def run
      unless config[:lb_id].nil?
        ui.fatal("Must provide a Load Balancer ID")
        show_usage
        exit 1
      end

      unless (config.keys & [:by_name, :by_private_ip, :by_search]).any?
        ui.fatal("Must specify list of nodes")
        ui.fatal("Must provide nodes via --by-name, --by-private-ip, or --by-search\n")
        show_usage
        exit 2
      end

      node_ips = get_node_ips({
        :by_search     => config[:by_search],
        :by_name       => config[:by_name],
        :by_private_ip => config[:by_private_ip]
      })

      nodes = node_ips.map do |ip|
        {
          :address => ip,
          :port => config[:auto_resolve_port] ? "port" : config[:node_port],
          :condition => config[:node_condition],
          :weight => config[:weight]
        }
      end

      if nodes.empty?
        ui.fatal("Chef search has not returned any of the specified nodes")
        exit 3
      end

      loadbalancers = connection.list_load_balancers.body["loadBalancers"].map {|lb| lb["id"].to_s}
      if loadbalancers.empty?
        ui.fatal("No Load Balancers have been found")
        exit 4
      end

      if ! loadbalancers.include? config[:lb_id]
        ui.fatal("Could not find Load Balancer #{config[:lb_id]} in your Rackspace Cloud account")
        exit 5
      end

      unless config[:force]
        ui.confirm("Do you really want to add these nodes")
      end

      loadbalancer = connection.get_load_balancer(config[:lb_id]).body["loadBalancer"]
      lb_nodes = loadbalancer["nodes"]
      lb_nodes_ips = lb_nodes.map {|lb_node| lb_node[:address]}
      
      if config[:auto_resolve_port]
        nodes.each do |n|
          n[:port] = lb_nodes.first[:port]
        end
      end
      
      nodes_for_lb = nodes.reject do |node|
        if lb_nodes_ips.include?(node[:address])
          ui.warn("#{node[:address]} is already behind #{config[:lb_id]} Load Balancer")
        end
        lb_nodes_ips.include?(node[:address])
      end

      unless nodes_for_lb.empty?
        nodes_for_lb.each do |node|
          ui.output(ui.color("Adding node[:address] to Load Balancer #{config[:lb_id]} pool", :green, :bold))
          response = connection.create_node(node[:address], node[:port], node[:condition], node[:weight])
          if [200,202].include?(response.status)
                ui.output(ui.color("node[:address] added successfully", :green, :bold))
          else
                ui.output(ui.color("node[:address] addition failed", :red, :bold))
          end
        end
      end
      ui.output(ui.color("Complete", :green))
    end
  end
end
