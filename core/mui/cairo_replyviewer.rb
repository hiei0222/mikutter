# -*- coding: utf-8 -*-

miquire :mui, 'sub_parts_helper'

require 'gtk2'
require 'cairo'

class Gdk::ReplyViewer < Gdk::SubParts

  attr_reader :icon_width, :icon_height

  def initialize(*args)
    super
    @icon_width, @icon_height, @margin = 24, 24, 2
  end

  def render(context)
    if(message and helper.visible?)
      context.save{
        context.translate(@margin, 0)
        render_main_icon(context)
        context.translate(@icon_width + @margin, 0)
        context.set_source_rgb(*(UserConfig[:mumble_reply_color] || [0,0,0]).map{ |c| c.to_f / 65536 })
        context.show_pango_layout(main_message(context)) } end end

  def height
    if helper.to_message.has_receive_message?
      icon_height
    else
      0 end end

  private

  def message
    if(helper.to_message.has_receive_message?)
      @message ||= lambda{
        result = helper.to_message.receive_message
        if(UserConfig[:retrieve_force_mumbleparent] and not result)
          Thread.new{
            @message = helper.to_message.receive_message(true)
            helper.on_modify
            #  helper.reset_height if @message != nil
          } end
        result }.call end end

  def escaped_main_text
    message.to_show.gsub(/[<>&]/){|m| {'&' => '&amp;' ,'>' => '&gt;', '<' => '&lt;'}[$0] }.freeze end
  memoize :escaped_main_text

  def main_message(context = dummy_context)
    attr_list, text = Pango.parse_markup(escaped_main_text)
    layout = context.create_pango_layout
    layout.width = (width - @icon_width - @margin*3) * Pango::SCALE
    layout.attributes = attr_list
    layout.wrap = Pango::WRAP_CHAR
    layout.font_description = Pango::FontDescription.new(UserConfig[:mumble_reply_font])
    layout.text = text
    layout end

  def render_main_icon(context)
    context.set_source_pixbuf(main_icon)
    context.paint
  end

  def main_icon
    @main_icon ||= Gtk::WebIcon.get_icon_pixbuf(message[:user][:profile_image_url], icon_width, icon_height){ |pixbuf|
      @main_icon = pixbuf
      helper.on_modify } end

end
