#! /usr/bin/ruby
# -*- coding: utf-8 -*-

Dir.chdir(File.join(File.dirname($0), 'core'))

require 'utils'
miquire :core, 'environment'
miquire :core, 'watch'
miquire :core, 'post'
miquire :mui, 'extension'
miquire :core, 'delayer'

require 'benchmark'
require 'webrick' # require to daemon
require 'thread'
require 'fileutils'

Thread.abort_on_exception = true

def boot()
  logfile(Environment::LOGDIR)
  #if(already_exists_another_instance?) then
  #  error('Already exist another instance')
  #  exit!
  #end
  include File::Constants
  if $daemon then
    WEBrick::Daemon.start{
      main()
    }
  else
    main()
  end
  return true
end

def create_pidfile()
  begin
    open(Environment::PIDFILE, WRONLY|CREAT|EXCL){ |output|
      output.write(Process.pid)
    }
  rescue Errno::EEXIST
    error('to write pid file failed.')
    exit
  end
end

def already_exists_another_instance?
  if FileTest.exist? Environment::PIDFILE then
    open(Environment::PIDFILE){|out|
      pid = out.read
      if pid_exist?(pid) then
        notice "process #{pid} already exist"
        return true
      else
        File::delete(Environment::PIDFILE)
        notice "pid file exist. however, process #{pid} not found"
        return false
      end
    }
    error 'pid file can\'t open'
    exit
  else
    notice 'pid file not found'
  end
  return false
end

def argument_parser()
  $debug = false
  $learnable = true
  $daemon = false
  $interactive = false
  $quiet = false
  $single_thread = false

  ARGV.each{ |arg|
    case arg
    when '-i' # インタラクティブモード(default:off)
      $interactive = true
    when '--debug' # デバッグモード(default:off)
      $debug = true
      seterrorlevel(:notice)
    when '-d' # デーモンモード(default:off)
      $daemon = true
    when '-l' # タグを学習しない(default:する)
      $learnable = false
    when '-q'
      $quiet = true
    when '-s' # シングルスレッドモード。他のスレッドがGTKのレンダリングを妨げる環境用
      $single_thread = true
    end
  }
end

def main()
  #create_pidfile
  notice Environment::VERSION

  if $debug then
    notice '-- loaded plugins'
    Plugin::Ring.avail_plugins.each_pair{|name, insts|
      inst = insts.map{|inst| inst.class }.join(', ')
      notice "#{name}: #{inst}"
    }
    notice '--'
  end

  watch = Watch.instance

  if($interactive) then
    loop{
      print '> '
      input = STDIN.gets.chomp
      case (input)
      when 'q'
        exit
      when 'help'
        puts 'exit: "q"'
      else
        watch.action(Message.new(input, :user => Hash[:id, 0, :idname, 'toshi_a']))
      end
    }
  else
    count = 600
    Gtk.timeout_add(100){
      Gtk::Lock.unlock
      if(count > 600) then
        notice 'run'
        watch.action
        count = 0
      end
      count += 1
      Delayer.run
      Gtk::Lock.lock
      true
    }
    Gtk::Lock.lock
    Gtk.main
  end
end

def gen_xml(msg)
  xml = REXML::Document.new open('chi_timeline_cachereplies')
  status = xml.root.get_elements('//statuses/status/').first
  status.get_elements('text').first.add_text(msg)
  return xml
end

FileUtils.mkdir_p(File.expand_path(Environment::TMPDIR))

errfile = File.join(File.expand_path(Environment::TMPDIR), 'mikutter_dump')
if File.exist?(errfile)
  File.rename(errfile, File.expand_path(File.join(Environment::TMPDIR, 'mikutter_error')))
end

argument_parser()

begin
  $stderr = File.open(errfile, 'w') if not $debug
  boot()
  errlog.close
  File.delete(errfile)
ensure
  # $stderr.close if errlog.closed?
end
