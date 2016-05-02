module VSphereCloud
  class VmConfig

    def initialize(manifest_params:, cluster_picker: cluster_picker, datastore_picker: datastore_picker)
      @manifest_params = manifest_params
      @cluster_picker = cluster_picker
      @datastore_picker = datastore_picker
    end

    def name
      @vm_cid ||= "vm-#{SecureRandom.uuid}"
    end

    def cluster_name
      return clusters_spec.keys.first if clusters_spec.keys.first
      return nil if @cluster_picker.nil?
      return @cluster_name if @cluster_name

      @cluster_picker.update(available_clusters)

      total_eph_disk_size = ephemeral_disk_size + config_spec_params[:memory_mb] + stemcell_size
      @cluster_name = @cluster_picker.pick_cluster(config_spec_params[:memory_mb], total_eph_disk_size, existing_disks)
    end

    # TODO: Remove this once we handle placement resources better
    def is_top_level_cluster
      return true if clusters_spec.keys.first
    end

    # TODO: Remove this once we handle placement resources better
    def cluster_spec
        return clusters_spec.values.first
    end

    def drs_rule
      cluster_config = clusters_spec.values.first
      return nil if cluster_config.nil?

      (cluster_config["drs_rules"] || []).first
    end

    def datastore_name
      return nil if @datastore_picker.nil?
      return @datastore_name if @datastore_name

      cluster_properties = available_clusters[cluster_name]
      return nil if cluster_properties.nil?

      @datastore_picker.update(cluster_properties[:datastores])
      @datastore_name = @datastore_picker.pick_datastore(ephemeral_disk_size, @manifest_params[:ephemeral_datastore_pattern])
    end

    def ephemeral_disk_size
      resource_pool["disk"]
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
      params[:num_cpus] = resource_pool['cpu']
      params[:memory_mb] = resource_pool['ram']
      params[:nested_hv_enabled] = true if resource_pool['nested_hardware_virtualization']
      params[:cpu_hot_add_enabled] = true if resource_pool['cpu_hot_add_enabled']
      params[:memory_hot_add_enabled] = true if resource_pool['memory_hot_add_enabled']
      params.delete_if { |k, v| v.nil? }
    end

    def validate
      validate_drs_rules
    end

    def validate_drs_rules
      cluster_config = clusters_spec.values.first
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

    private

    def resource_pool
      @manifest_params[:resource_pool] || {}
    end

    def available_clusters
      @manifest_params[:available_clusters] || {}
    end

    def stemcell
      @manifest_params[:stemcell] || {}
    end

    def existing_disks
      @manifest_params[:existing_disks] || {}
    end

    def datacenters_spec
      resource_pool['datacenters'] || []
    end

    def clusters_spec
      datacenter_spec = datacenters_spec.first || {}
      datacenter_spec.fetch('clusters', []).first || {}
    end
  end
end
