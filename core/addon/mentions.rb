
miquire :addon, 'addon'

module Addon
  class Mention < Addon

    get_all_parameter_once :mention

    def onboot(watch)
      @main = Gtk::TimeLine.new()
      self.regist_tab(watch, @main, 'Me', "core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}reply.png")
    end

    def onmention(messages)
      @main.add(messages.map{ |m| m[1] })
    end

  end
end

Plugin::Ring.push Addon::Mention.new,[:boot, :mention]
