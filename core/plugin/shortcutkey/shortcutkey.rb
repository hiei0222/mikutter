# -*- coding:utf-8 -*-

Plugin.create :shortcutkey do
  class ShortcutKeyListView < ::Gtk::CRUD

    COLUMN_KEYBIND = 0
    COLUMN_COMMAND_ICON = 1
    COLUMN_COMMAND = 2
    COLUMN_SLUG = 3
    COLUMN_ID = 4

    def initialize
      super
      commands = Plugin.filtering(:command, Hash.new).first
      shortcutkeys.each{ |id, behavior|
        slug = behavior[:slug]
        iter = model.append
        iter[COLUMN_ID] = id
        iter[COLUMN_KEYBIND] = behavior[:key]
        iter[COLUMN_COMMAND] = behavior[:name]
        iter[COLUMN_SLUG] = slug
        if commands[slug]
          icon = commands[slug][:icon]
          icon = icon.call(nil) if icon.is_a? Proc
          if icon
            iter[COLUMN_COMMAND_ICON] = Gdk::WebImageLoader.pixbuf(icon, 16, 16){ |pixbuf|
              if not destroyed?
                iter[COLUMN_COMMAND_ICON] = pixbuf end } end end } end

    def column_schemer
      [{:kind => :text, :widget => :keyconfig, :type => String, :label => 'キーバインド'},
       [{:kind => :pixbuf, :type => Gdk::Pixbuf, :label => '機能名'},
        {:kind => :text, :type => String, :expand => true}],
       {:kind => :text, :widget => :chooseone, :args => [Hash[Plugin.filtering(:command, Hash.new).first.values.map{ |x|
                                                            [x[:slug], x[:name]]
                                                          }].freeze],
         :type => Symbol},
       {:type => Integer},
      ].freeze
    end

    def shortcutkeys
      (UserConfig[:shortcutkey_keybinds] || Hash.new).dup end

    def new_serial
      @new_serial ||= (shortcutkeys.keys.max || 0)
      @new_serial += 1 end

    def on_created(iter)
      bind = shortcutkeys
      name = Plugin.filtering(:command, Hash.new).first[iter[COLUMN_SLUG].to_sym][:name]
      name = name.call(nil) if name.is_a? Proc
      iter[COLUMN_ID] = new_serial
      bind[iter[COLUMN_ID]] = {
        :key => iter[COLUMN_KEYBIND].to_s,
        :name => name,
        :slug => iter[COLUMN_SLUG].to_sym }
      iter[COLUMN_COMMAND] = name
      UserConfig[:shortcutkey_keybinds] = bind
    end

    def on_updated(iter)
      bind = shortcutkeys
      name = Plugin.filtering(:command, Hash.new).first[iter[COLUMN_SLUG].to_sym][:name]
      name = name.call(nil) if name.is_a? Proc
      bind[iter[COLUMN_ID].to_i] = {
        :key => iter[COLUMN_KEYBIND].to_s,
        :name => name,
        :slug => iter[COLUMN_SLUG].to_sym }
      iter[COLUMN_COMMAND] = name
      UserConfig[:shortcutkey_keybinds] = bind
    end

    def on_deleted(iter)
      bind = shortcutkeys
      bind.delete(iter[COLUMN_ID].to_i)
      UserConfig[:shortcutkey_keybinds] = bind
    end

  end

  filter_keypress do |key, widget, executed|
    type_strict key => String, widget => Plugin::GUI::Widget
    notice "key pressed #{key} #{widget.inspect}"
    keybinds = (UserConfig[:shortcutkey_keybinds] || Hash.new)
    commands = lazy{ Plugin.filtering(:command, Hash.new).first }
    timeline = widget.is_a?(Plugin::GUI::Timeline) ? widget : widget.active_class_of(Plugin::GUI::Timeline)
    event = Plugin::GUI::Event.new(:contextmenu, widget, timeline ? timeline.selected_messages : [])
    keybinds.values.each{ |behavior|
      if behavior[:key] == key
        cmd = commands[behavior[:slug]]
        if cmd and widget.class.find_role_ancestor(cmd[:role])
          if cmd[:condition] === event
            notice "command executed :#{behavior[:slug]}"
            executed = true
            cmd[:exec].call(event) end end end }
    [key, widget, executed] end

  settings "ショートカットキー" do
    listview = ShortcutKeyListView.new
    pack_start(Gtk::HBox.new(false, 4).add(listview).closeup(listview.buttons(Gtk::VBox)))
  end

end
