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

class Chef
  class Knife
    module RackspaceLoadBalancerNodes

      def search_nodes(query)
        nodes = []
        Chef::Search::Query.new.search(:node, query) do |n|
          nodes << n
        end

        nodes
      end

      def get_node_ips(options)
        node_ips = []

        if options[:by_search]
          nodes_from_chef = search_nodes(options[:by_search])
          node_ips.concat(find_internal_ip(nodes_from_chef))
        end

        if options[:by_name]
          node_names = options[:by_name].split(",")
          nodes_from_chef = search_nodes(
            node_names.map {|n| "name:#{n}"}.join(" OR ")
          )
          node_ips.concat(find_internal_ip(nodes_from_chef))
        end

        if options[:by_private_ip]
          node_ips.concat(options[:by_private_ip].split(","))
        end

        # No duplicates!
        node_ips.uniq
      end

      def resolve_node_name_from_ip(ip)
        nodes = search_nodes("network_interfaces_eth1_addresses:#{ip}")
        nodes.first.fqdn unless nodes.nil?
      end

      private

      def find_internal_ip(nodes)
        nodes.map do |node|
          node.network["interfaces"]["eth1"]["addresses"].keys.detect do |ip|
            ip =~ /10\./
          end
        end
      end
    end
  end
end
