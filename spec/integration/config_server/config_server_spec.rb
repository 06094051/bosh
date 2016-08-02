require 'spec_helper'

describe 'using director with config server', type: :integration do
  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, :preserve => true)
    bosh_runner.run_in_dir('create release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload release', ClientSandbox.links_release_dir)
  end

  let (:manifest_hash) { Bosh::Spec::Deployments.simple_manifest }
  let (:cloud_config)  { Bosh::Spec::Deployments.simple_cloud_config }
  let (:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox)}

  context 'when config server certificates are not trusted' do
    with_reset_sandbox_before_each(config_server_enabled: true, with_config_server_trusted_certs: false, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

    before do
      bosh_runner.run("target #{current_sandbox.director_url}", {ca_cert: current_sandbox.certificate_path})
      bosh_runner.run('logout')
      bosh_runner.run_interactively('login') do |runner|
        runner.send_keys 'marissa'
        runner.send_keys 'koala'
        runner.send_keys '' # UAA only uses this for SAML, but always prompts for it
      end
    end

    it 'throws certificate validator error' do
      manifest_hash['jobs'].first['properties'] = {'test_property' => '((test_property))'}
      output, exit_code = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)

      expect(exit_code).to_not eq(0)
      expect(output).to include('Error 100: SSL certificate verification failed')
    end
  end

  context 'when config server certificates are trusted' do
    with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

    before do
      bosh_runner.run("target #{current_sandbox.director_url}", {ca_cert: current_sandbox.certificate_path})
      bosh_runner.run('logout')
      bosh_runner.run_interactively('login') do |runner|
        runner.send_keys 'marissa'
        runner.send_keys 'koala'
        runner.send_keys '' # UAA only uses this for SAML, but always prompts for it
      end
    end

    context 'when deployment manifest has placeholders' do
      it 'raises an error when config server does not have values for placeholders' do
        manifest_hash['jobs'].first['properties'] = {'test_property' => '((test_property))'}
        output, exit_code = deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, failure_expected: true, return_exit_code: true)

        expect(exit_code).to_not eq(0)
        expect(output).to include('Failed to find keys in the config server: test_property')
      end

      it 'replaces placeholders in the manifest when config server has value for placeholders' do
        config_server_helper.put_value('test_property', 'cats are happy')
        manifest_hash['jobs'].first['properties'] = {'test_property' => '((test_property))'}

        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
        vm = director.vm('foobar', '0')

        template = vm.read_job_template('foobar', 'bin/foobar_ctl')
        expect(template).to include('test_property=cats are happy')
      end
    end

    context 'when runtime manifest has placeholders' do
      let(:runtime_config) { Bosh::Spec::Deployments.runtime_config_with_addon_placeholders }

      it 'replaces placeholders in the addons' do
        config_server_helper.put_value('release_name', 'dummy2')
        config_server_helper.put_value('addon_prop', 'i am Groot')
        config_server_helper.put_value('test_property', 'cats are happy')
        manifest_hash['jobs'].first['properties'] = {'test_property' => '((test_property))'}

        bosh_runner.run_in_dir("upload release #{spec_asset('dummy2-release.tgz')}", ClientSandbox.test_release_dir)
        deploy_from_scratch(no_login: true, manifest_hash: manifest_hash, cloud_config_hash: cloud_config, runtime_config_hash: runtime_config)

        vm = director.vm('foobar', '0')
        template = vm.read_job_template('dummy_with_properties', 'bin/dummy_with_properties_ctl')
        expect(template).to include("echo 'i am Groot'")
      end
    end

    context 'when running an errand that has placeholders' do
      let(:errand_manifest){ Bosh::Spec::Deployments.manifest_errand_with_placeholders }

      it 'replaces placeholder in properties' do
        config_server_helper.put_value('placeholder', 'test value')
        deploy_from_scratch(no_login: true, manifest_hash: errand_manifest, cloud_config_hash: cloud_config)
        errand_result = bosh_runner.run('run errand fake-errand-name --keep-alive')

        expect(errand_result).to include('test value')
      end
    end

    context 'when links exist' do

      let(:cloud_config) do
        cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config_hash['azs'] = [{ 'name' => 'z1' }]
        cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13']
        cloud_config_hash['networks'].first['subnets'].first['az'] = 'z1'
        cloud_config_hash['compilation']['az'] = 'z1'
        cloud_config_hash['networks'] << {
            'name' => 'dynamic-network',
            'type' => 'dynamic',
            'subnets' => [{'az' => 'z1'}]
        }

        cloud_config_hash
      end

      let(:my_job) do
        job_spec = Bosh::Spec::Deployments.simple_job(
            name: 'my_job',
            templates: [
                {'name' => 'http_server_with_provides'},
                {'name' => 'http_proxy_with_requires'},
            ],
            instances: 1
        )
        job_spec['azs'] = ['z1']
        job_spec['properties'] = {'listen_port' => 9035, 'name_space' => {'fibonacci' => '((fibonacci_placeholder))'}}
        job_spec
      end

      let(:manifest) do
        manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
        manifest['jobs'] = [my_job]
        manifest['properties'] = {'listen_port' => 9999}
        manifest
      end

      before do
        upload_links_release
        upload_stemcell

        upload_cloud_config(cloud_config_hash: cloud_config)
      end

      it 'replaces the placeholder values of properties consumed through links' do
        config_server_helper.put_value('fibonacci_placeholder', 'fibonacci_value')
        deploy_simple_manifest(manifest_hash: manifest)

        link_vm = director.vm('my_job', '0')
        template = YAML.load(link_vm.read_job_template('http_proxy_with_requires', 'config/config.yml'))
        expect(template['links']['properties']['fibonacci']).to eq('fibonacci_value')
      end

      context 'when manual links are involved' do
        let (:job_with_manual_consumes_link) do
          job_spec = Bosh::Spec::Deployments.simple_job(
              name: 'property_job',
              templates: [{
                              'name' => 'consumer',
                              'consumes' => {
                                  'provider' => {
                                      'properties' => {'a' => '((a_placeholder))', 'b' => '((b_placeholder))', 'c' => '((c_placeholder))'},
                                      'instances' => [{'name' => 'external_db', 'address' => '192.168.15.4'}],
                                      'networks' => {'network_1' => 2, 'network_2' => 3}
                                  }
                              }
                          }],
              instances: 1,
              static_ips: ['192.168.1.10'],
              properties: {}
          )
          job_spec['azs'] = ['z1']
          job_spec['networks'] << {
              'name' => 'dynamic-network',
              'default' => ['dns', 'gateway']
          }
          job_spec
        end

        it 'resolves the properties defined inside the links section of the deployment manifest' do
          config_server_helper.put_value('a_placeholder', 'a_value')
          config_server_helper.put_value('b_placeholder', 'b_value')
          config_server_helper.put_value('c_placeholder', 'c_value')

          manifest['jobs'] = [job_with_manual_consumes_link]

          deploy_simple_manifest(manifest_hash: manifest)

          link_vm = director.vm('property_job', '0')

          template = YAML.load(link_vm.read_job_template('consumer', 'config.yml'))

          expect(template['a']).to eq('a_value')
          expect(template['b']).to eq('b_value')
          expect(template['c']).to eq('c_value')
        end
      end
    end
  end
end
