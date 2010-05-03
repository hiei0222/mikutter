
miquire :addon, 'addon'

module Addon
  class FriendTimeline < Addon

    get_all_parameter_once :update

    def onboot(watch)
      @main = Gtk::TimeLine.new()
      self.regist_tab(watch, @main, 'TL', "core#{File::SEPARATOR}skin#{File::SEPARATOR}data#{File::SEPARATOR}timeline.png")
    end

    def onupdate(messages)
      @main.add(messages.map{ |m| m[1] })
    end

  end
end

Plugin::Ring.push Addon::FriendTimeline.new,[:boot, :update]
