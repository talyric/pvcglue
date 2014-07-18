# Based on https://github.com/emancu/toml-rb/blob/master/lib/toml/dumper.rb
module TOML
  class PvcDumper
    attr_reader :toml_str

    def initialize(hash)
      @toml_str = ''

      visit(hash, '')
    end

    private

    def visit(hash, prefix, level = 0)
      nested_pairs = []
      simple_pairs = []
      indent_prefix = ' '*[level-1,0].max*2
      indent_values = ' '*([level-1, 0].max*2+2)

      if level == 1
        @toml_str += "\n" unless @toml_str.empty?
        @toml_str += "################################################################################\n"
        @toml_str += "#  === #{prefix} ===\n"
        @toml_str += "################################################################################\n"
      end

      hash.keys.sort.each do |key|
        val = hash[key]
        (val.is_a?(Hash) ? nested_pairs : simple_pairs) << [key, val]
      end

      @toml_str += "\n#{indent_prefix}[#{prefix}]\n" unless prefix.empty? || simple_pairs.empty?

      # First add simple pairs, under the prefix
      simple_pairs.each do |key, val|
        @toml_str << "#{indent_values}#{key.to_s} = #{to_toml(val)}\n"
      end

      nested_pairs.each do |key, val|
        visit(val, prefix.empty? ? key.to_s : [prefix, key].join('.'), level+1)
      end
    end

    def to_toml(obj)
      case
        when obj.is_a?(Time)
          obj.strftime('%Y-%m-%dT%H:%M:%SZ')
        else
          obj.inspect
      end
    end
  end
end
