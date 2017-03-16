module Pvcglue
  class Docs
    ROLLS = {
      lb: 'Load Balancer'
    }

    def initialize(enabled)
      @enabled = enabled
      @data = []
    end

    attr_accessor :enabled, :data, :current_minion, :collecting

    def add(s)
      return unless collecting
      data << s
    end

    def add_paragraph(text)
      add('')
      add(text)
      add('')
    end

    def add_annotation(text)
      add('')
      add("> #{text}")
      add('')
    end


    def level_1_roles(minion)
      return unless enabled
      self.current_minion = minion
      if minion
        self.collecting = true
        level_1(minion.roles.map { |role| ROLLS[role.to_sym] || role }.join(', '))
      else
        self.collecting = false
      end
    end

    def level_1(heading)
      return unless enabled
      add_header(1, heading)
    end

    def level_2(heading)
      return unless enabled
      add_header(2, heading)
    end

    def add_header(level, heading)
      return unless enabled
      add('')
      add("#{'#'*level} #{heading}")
    end

    def set_item(options)
      unless enabled
        yield
        return
      end
      options = ::SafeMash.new(options)
      add_header(3, options.heading)
      add('----')
      yield
      add_paragraph(options.body) if options.body && options.body.present?
      if options.reference && options.reference.present?
        add('')
        add("See also:  [#{options.reference}](#{options.reference})")
      end
    end

    def log_file_write(options)
      return unless enabled
      options = ::SafeMash.new(options)
      add_annotation("Write data to `#{options.file}`")
      add_block(options)
    end

    def log_cmd(cmd)
      return unless enabled
      # add_block(data: cmd, style: 'shell')
      add("> `> #{cmd}`<br />")
    end

    def add_block(options)
      options = ::SafeMash.new(options)
      add("```#{options.style}")
      add(options.data)
      add('```')
    end

    def done
      return unless enabled
      File.write('/home/andrew/projects/slate-pvc/source/includes/_logs.md', data.join("\n"))
    end
  end
end
