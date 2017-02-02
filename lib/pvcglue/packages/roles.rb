module Pvcglue
  class Packages
    class Roles < Pvcglue::Packages
      def installed?
        false
      end

      def post_install_check?
        true
      end

      def install!
        Pvcglue::Packages::LoadBalancer.apply(minion) if has_role?(:lb)
        Pvcglue::Packages::Web.apply(minion) if has_role?(:web)
        Pvcglue::Packages::Worker.apply(minion) if has_role?(:worker)
        Pvcglue::Packages::Pg.apply(minion) if has_role?(:pg)
        Pvcglue::Packages::Memcache.apply(minion) if has_role?(:mc)
        Pvcglue::Packages::Redis.apply(minion) if has_role?(:redis)
      end
    end
  end
end
