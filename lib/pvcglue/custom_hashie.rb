class SafeMash < Hashie::Mash
  include Hashie::Extensions::Mash::SafeAssignment
end

# class OverrideMash < Hashie::Mash
#   disable_warnings
#   include Hashie::Extensions::MethodAccessWithOverride
# end
