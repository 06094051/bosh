module Bosh::Director
  module DeploymentPlan
    class IpProviderV2
      include IpUtil

      def initialize(ip_repo, vip_repo, using_global_networking, logger)
        @logger = Bosh::Director::TaggedLogger.new(logger, 'network-configuration')
        @ip_repo = ip_repo
        @using_global_networking = using_global_networking
        @vip_repo = vip_repo
      end

      def release(reservation)
        return if reservation.network.is_a?(DynamicNetwork)

        if reservation.ip.nil?
          @logger.error("Failed to release IP for manual network '#{reservation.network.name}': IP must be provided")
          raise Bosh::Director::NetworkReservationIpMissing, "Can't release reservation without an IP"
        else
          ip_repo = reservation.network.is_a?(VipNetwork) ? @vip_repo : @ip_repo
          ip_repo.delete(reservation.ip, reservation.network.name)
        end
      end

      def reserve(reservation)
        # We should not be calling reserve on reservations that have already been reserved
        return if reservation.reserved?

        # Do nothing for Dynamic Network
        return if reservation.network.is_a?(DynamicNetwork)

        # Reserve IP for VIP Network
        return reserve_vip(reservation) if reservation.network.is_a?(VipNetwork)

        # Reserve IP for Manual Network
        if reservation.ip.nil?
          @logger.debug("Allocating dynamic ip for manual network '#{reservation.network.name}'")

          filter_subnet_by_instance_az(reservation).each do |subnet|
            ip = @ip_repo.allocate_dynamic_ip(reservation, subnet)

            if ip
              @logger.debug("Reserving dynamic IP '#{format_ip(ip)}' for manual network '#{reservation.network.name}'")
              reservation.resolve_ip(ip)
              reservation.resolve_type(:dynamic)
              reservation.mark_reserved
              return
            end
          end

          raise NetworkReservationNotEnoughCapacity,
            "Failed to reserve IP for '#{reservation.instance}' for manual network '#{reservation.network.name}': no more available"

        else

          cidr_ip = format_ip(reservation.ip)
          @logger.debug("Reserving #{reservation.desc} for manual network '#{reservation.network.name}'")

          subnet = find_subnet_containing(reservation)

          if subnet
            if subnet.restricted_ips.include?(reservation.ip.to_i)
              message = "Failed to reserve IP '#{format_ip(reservation.ip)}' for network '#{subnet.network.name}': IP belongs to reserved range"
              @logger.error(message)
              raise Bosh::Director::NetworkReservationIpReserved, message
            end

            @ip_repo.add(reservation)

            mark_reserved_with_reservation_type(reservation, subnet)
          else
            raise NetworkReservationIpOutsideSubnet,
              "Provided static IP '#{cidr_ip}' does not belong to any subnet in network '#{reservation.network.name}'"
          end
        end
      end

      def reserve_existing_ips(reservation)
        @logger.debug('Reserving existing ips')
        subnet = find_subnet_containing(reservation)
        if subnet
          return if subnet.restricted_ips.include?(reservation.ip.to_i)
          @ip_repo.add(reservation)

          @logger.debug("Marking existing IP #{format_ip(reservation.ip)} as reserved")
          mark_reserved_with_reservation_type(reservation, subnet)
        end
      end

      private

      def mark_reserved_with_reservation_type(reservation, subnet)
        if subnet.static_ips.include?(reservation.ip.to_i)
          reservation.resolve_type(:static)
          reservation.mark_reserved
          @logger.debug("Found subnet for #{format_ip(reservation.ip)}. Reserved as static network reservation.")
        else
          reservation.resolve_type(:dynamic)
          reservation.mark_reserved
          @logger.debug("Found subnet for #{format_ip(reservation.ip)}. Reserved as dynamic network reservation.")
        end
      end

      def reserve_vip(reservation)
        reservation.resolve_type(:static)

        @logger.debug("Reserving IP '#{format_ip(reservation.ip)}' for vip network '#{reservation.network.name}'")
        @vip_repo.add(reservation)
        reservation.mark_reserved
      end

      def filter_subnet_by_instance_az(reservation)
        instance_az = reservation.instance.availability_zone
        if instance_az.nil?
          reservation.network.subnets
        else
          reservation.network.subnets.select do |subnet|
            subnet.availability_zone_names.include?(instance_az.name)
          end
        end
      end

      def find_subnet_containing(reservation)
        reservation.network.subnets.find { |subnet| subnet.range.contains?(reservation.ip) }
      end
    end
  end
end
