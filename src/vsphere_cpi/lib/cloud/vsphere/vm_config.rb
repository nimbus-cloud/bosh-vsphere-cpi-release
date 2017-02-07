module VSphereCloud
  class VmConfig

    def initialize(manifest_params:, cluster_picker: nil)
      @manifest_params = manifest_params
      @cluster_picker = cluster_picker
    end

    def name
      @vm_cid ||= "vm-#{SecureRandom.uuid}"
    end

    def cluster_name
      return @cluster_name if @cluster_name

      return nil if @cluster_picker.nil?

      @cluster_name = cluster_placement.keys.first
    end

    def has_custom_cluster_properties?
      # custom properties include drs_rules and vcenter resource_pools
      !!resource_pool_clusters_spec.keys.first
    end

    def cluster_spec
      return resource_pool_clusters_spec.values.first
    end

    def drs_rule
      cluster_config = resource_pool_clusters_spec.values.first
      return nil if cluster_config.nil?

      (cluster_config["drs_rules"] || []).first
    end

    def ephemeral_datastore_name
      return nil if cluster_name.nil?
      return @datastore_name if @datastore_name

      ephemeral_disk = disk_configurations.find { |disk| disk[:ephemeral] }
      cluster_placement[cluster_name][ephemeral_disk]
    end

    def ephemeral_disk_size
      vm_type["disk"]
    end

    def stemcell_cid
      stemcell[:cid]
    end

    def stemcell_size
      stemcell[:size]
    end

    def agent_id
      @manifest_params[:agent_id]
    end

    def agent_env
      @manifest_params[:agent_env]
    end

    def networks_spec
      @manifest_params[:networks_spec] || {}
    end

    def vsphere_networks
      networks_map = {}
      networks_spec.each_value do |network_spec|
        cloud_properties = network_spec['cloud_properties']
        unless cloud_properties.nil? || cloud_properties['name'].nil?
          name = cloud_properties['name']
          networks_map[name] ||= []
          networks_map[name] << network_spec['ip']
        end
      end
      networks_map
    end

    def config_spec_params
      params = {}
      # nimbus2 stuff - force memory allocation - start
      params[:memory_allocation] = VimSdk::Vim::ResourceAllocationInfo.new(reservation: vm_type['ram']) if vm_type['ram']
      # nimbus2 stuff - force memory allocation - end
      params[:num_cpus] = vm_type['cpu']
      params[:memory_mb] = vm_type['ram']
      params[:nested_hv_enabled] = true if vm_type['nested_hardware_virtualization']
      params[:cpu_hot_add_enabled] = true if vm_type['cpu_hot_add_enabled']
      params[:memory_hot_add_enabled] = true if vm_type['memory_hot_add_enabled']
      params.delete_if { |k, v| v.nil? }
    end

    def validate
      validate_drs_rules
    end

    def validate_drs_rules
      cluster_config = resource_pool_clusters_spec.values.first
      return if cluster_config.nil?

      drs_rules = cluster_config["drs_rules"]
      return if drs_rules.nil?

      if drs_rules.size > 1
        raise 'vSphere CPI supports only one DRS rule per resource pool'
      end

      rule_config = drs_rules.first

      if rule_config['type'] != 'separate_vms'
        raise "vSphere CPI only supports DRS rule of 'separate_vms' type, not '#{rule_config['type']}'"
      end
    end

    def bosh_group
      if !agent_env['bosh'].nil? then
        return agent_env['bosh']['group']
      else
        return nil
      end
    end

    private

    def vm_type
      @manifest_params[:vm_type] || {}
    end

    def available_clusters
      if resource_pool_cluster_name
        if global_clusters[resource_pool_cluster_name].nil?
          raise Bosh::Clouds::CloudError, "Cluster '#{resource_pool_cluster_name}' does not match global clusters [#{global_clusters.keys.join(', ')}]"
        end
        return global_clusters.select { |k,_| k == resource_pool_cluster_name }
      end
      global_clusters
    end

    def resource_pool_cluster_name
      resource_pool_clusters_spec.keys.first || nil
    end

    def global_clusters
      @manifest_params[:global_clusters] || {}
    end

    def stemcell
      @manifest_params[:stemcell] || {}
    end

    def disk_configurations
      @manifest_params[:disk_configurations] || {}
    end

    def datacenters_spec
      vm_type['datacenters'] || []
    end

    def resource_pool_clusters_spec
      datacenter_spec = datacenters_spec.first || {}
      datacenter_spec.fetch('clusters', []).first || {}
    end

    def cluster_placement
      return @cluster_placement if @cluster_placement

      if available_clusters.empty?
        raise Bosh::Clouds::CloudError, "No valid clusters were provided"
      end
      if vm_type['ram'].nil?
        raise Bosh::Clouds::CloudError, "Must specify vm_types.cloud_properties.ram"
      end

      @cluster_picker.update(available_clusters)
      @cluster_placement = @cluster_picker.best_cluster_placement(
        req_memory: vm_type['ram'],
        disk_configurations: disk_configurations,
      )
    end
  end
end
