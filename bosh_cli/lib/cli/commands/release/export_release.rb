require 'cli/name_version_pair'
require 'cli/client/export_release_client'

module Bosh::Cli::Command
  module Release
    class ExportRelease < Base

      # bosh create release
      usage 'export release'
      desc 'Export the compiled release to a tarball. Release should be in the form of {name}/{version} and stemcell should be in the form of {operating system name}/{stemcell version}'

      def export(release, stemcell)
        auth_required
        deployment_required
        show_current_state

        deployment_name = prepare_deployment_manifest["name"]
        release = Bosh::Cli::NameVersionPair.parse(release)
        stemcell = Bosh::Cli::NameVersionPair.parse(stemcell)
        stemcell_os = stemcell.name

        nl
        say('Checking if release exists...')
        if !release_exists?(release.name, release.version)
          err("Release `#{release.name}/#{release.version}' does not exist")
        else
          say('Yes')
        end
        nl

        client = Bosh::Cli::Client::ExportReleaseClient.new(director)
        status, task_id = client.export(deployment_name, release.name, release.version, stemcell_os, stemcell.version)
        task_report(status, task_id)
      end

      def release_exists?(name, version)
        existing = director.list_releases.select do |rel|
          matching_version = rel["release_versions"].select do |ver|
            ver['version'] == version
          end
          rel['name'] == name && !matching_version.empty?
        end

        !existing.empty?
      end
    end
  end
end