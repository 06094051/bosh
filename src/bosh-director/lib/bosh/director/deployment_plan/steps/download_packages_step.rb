module Bosh::Director
  module DeploymentPlan
    module Steps
      class DownloadPackagesStep
        def initialize(base_job, deployment_plan)
          @base_job = base_job
          @logger = base_job.logger
          @deployment_plan = deployment_plan
          @event_log = Config.event_log
        end

        def perform
          hotswap_instance_plans = @deployment_plan.instance_plans_with_hot_swap_and_needs_shutdown
          instance_plans_missing_vms = @deployment_plan.instance_plans_with_missing_vms
          instance_plans_needing_packages = hotswap_instance_plans + instance_plans_missing_vms

          total = instance_plans_needing_packages.length
          event_log_stage = Config.event_log.begin_stage('Downloading packages', total)

          ThreadPool.new(max_threads: Config.max_threads, logger: @logger).wrap do |pool|
            instance_plans_needing_packages.each do |plan|
              instance_model = plan.instance.model

              pool.process do
                with_thread_name("download_package_for_instance(#{instance_model}/#{total})") do

                  event_log_stage.advance_and_track(instance_model.to_s) do
                    @logger.info("Downloading packages for instance #{instance_model.to_s}.")
                    instance_spec = InstanceSpec.create_from_instance_plan(plan)
                    agent = AgentClient.with_agent_id(instance_model.most_recent_inactive_vm.agent_id)
                    agent.prepare(instance_spec.as_jobless_apply_spec)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
