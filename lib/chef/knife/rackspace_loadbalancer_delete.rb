require 'chef/knife'
require 'chef/knife/rackspace_loadbalancer_base'
require 'chef/knife/rackspace_loadbalancer_show'
require 'fog'

module KnifePlugins
  class RackspaceLoadbalancerDelete < Chef::Knife
    include Chef::Knife::RackspaceLoadBalancerBase

    banner "knife rackspace loadbalancer delete ID [ID] (options)"

    option :force,
      :long => "--force",
      :description => "Skip user prompts"

    def run
      unless name_args.size >= 1
        ui.fatal("You must provide at least one Load Balancer ID!")
        show_usage
        exit 1
      end

      name_args.each do |lb_id|
        unless config[:force]
          ui.confirm("Do you really want to delete Load Balancer #{lb_id}")
        end

        load_balancer = connection.delete_load_balancer(lb_id)
        ui.warn("Deleted load balancer #{lb_id}")
      end
    end
  end
end
