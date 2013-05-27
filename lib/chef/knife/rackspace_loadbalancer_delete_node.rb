require 'chef/knife'
require 'chef/knife/rackspace_loadbalancer_base'
require 'chef/knife/rackspace_loadbalancer_nodes'
require 'fog'

module RackspaceService
  class RackspaceLoadbalancerAddNode < Chef::Knife
    include Chef::Knife::RackspaceLoadBalancerBase
    include Chef::Knife::RackspaceLoadBalancerNodes

    banner "knife rackspace loadbalancer delete node (options)"

    option :force,
      :long => "--force",
      :description => "Skip user input"

    option :lb_id,
      :long => "--loadbalancer-id ID",
      :description => "Load Balancer ID"

    option :by_name,
      :long => "--by-name \"NAME[,NAME]\"",
      :description => "Resolve names against chef server to produce list of nodes to add"

    option :by_private_ip,
      :long => "--by-private-ip \"IP[,IP]\"",
      :description => "List of nodes given by private ips to add"

    option :by_search,
      :long => "--by-search SEARCH",
      :description => "Resolve search against chef server to produce list of nodes to add"

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

      if nodes.empty?
        ui.fatal("Chef search has not returned any of the specified nodes")
        exit 3
      end

      loadbalancers = connection.list_load_balancers.body["loadBalancers"].map {|lb| lb["id"].to_s}
      if loadbalancers.empty?
        ui.fatal("No Load Balancers have been found")
        exit 4
      end

      if ! loadbalancers.include?(config[:lb_id])
        ui.fatal("Could not find Load Balancer #{config[:lb_id]} in your Rackspace Cloud account")
        exit 5
      end

      unless config[:force]
        ui.confirm("Do you really want to add these nodes")
      end

      loadbalancer = connection.get_load_balancer(config[:lb_id]).body["loadBalancer"]
      # keys are IP addresses, values are node ids
      lb_nodes = Hash[loadbalancer["nodes"].map { |n| [ n[:address], n[:id] ] }]

      nodes_to_remove = {}
      node_ips.each do |ip|
        if ! lb_nodes.keys.include?(ip)
          ui.warn("#{ip} is not int the #{config[:lb_id]} Load Balancer pool")
        end
        nodes_to_remove[ip] = lb_nodes[ip]
      end

      ui.warn("Removing #{nodes_to_remove.keys.join(',')} from Load Balancer #{config[:lb_id]}")
      response = connection.delete_nodes(config[:lb_id],nodes_to_remove.values)
      if [200,202].include?(response.status)
        ui.output(ui.color("Node deletion sucessful", :green, :bold))
      else
        ui.output(ui.color("Node deletion failed", :red, :bold))
      end

    end
  end
end
