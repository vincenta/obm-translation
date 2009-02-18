#!/usr/bin/env ruby

# This file is part of OBM-Translation.
#
# OBM-Translation is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or any later
# version.
#
# OBM-Translation is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with OBM-Translation. If not, see <http://www.gnu.org/licenses/>.



# todo :
#  - (GUI)        makes columns sortable
#  - (GUI)        put a * on modified files/languages
#  - (GUI & Core) display translation progresss stats
#  - (GUI & Core) use $VERBOSE & $DEBUG global variables to display debug informations
#  - (GUI & Core) a feature to automatically detect unused/missing variables from OBM GUI code source
#  - (Core)       manage file I/O permissions & errors
#  - (Core)       create a Controller class
#  - (Core)       write a smarter files parser
#  - (Core)       do not delete comments on modified lines when saving changes
#  - (GUI & Core) display status informations
#  - (GUI)        special editing tool for arrays
#  - (GUI & Core) allow to create a language
# maybe:
#  - (GUI & Core) display flag icons
#  - (GUI & Core) allow to change the reference language
#  - (Core)       save changes as a patch file ?
#  - (GUI & Core) implement undo/redo patern ?
#  - (GUI & Core) allow to add comment on a translation line
#             ex: $TheAnswer = "42"; //I think the problem is that the question was too broadly based...



require "obmtranslation/core"
require "obmtranslation/config"
require "obmtranslation/gui"



class Main
  include Singleton
  attr_reader :gui, :dictionnary

  def initialize
    Gtk.init
    @dictionnary = OBMtranslation::Dictionnary.new(OBMtranslation::Config::RefLang)
    @gui = nil
    @path = nil
    @lang = OBMtranslation::Config::DefLang
  end

  def build_gui
    @gui = OBMtranslation::GUI::MainWindow.instance
  end

  def start
    if @path.nil? then
      @gui.path_chooser.show(get_stored_path)
    else
      @gui.show_window
      Thread.new { open_dictionnary }
    end
    Gtk.main
  end

  def open_dictionnary(path=nil)
    set_path(path)
    @dictionnary.load(@path)
#    HowLongDoesItTakesTo? do @dictionnary.load(@path) end
    store_path(File.join(path,@lang))
#count = 0
#@dictionnary.lang['fr'].files.each{ |index,file| count += file.variables.length }
#print "#{count} variables\n"
#print "#{@dictionnary.lang.length} langues\n"
    @gui.set_lang_list(@dictionnary.lang_list)
    @gui.set_current_lang(@lang)
  end

  def set_path(path)
    @path = path unless path.nil? or not OBMtranslation::Dictionnary.dictionnary_folder?(path)
  end

  def set_lang(name)
    @lang = name unless name.nil?
  end

  def save_changes
    @dictionnary.save_changes
  end

  def store_path(path)
    File.open(OBMtranslation::Config::ConfigFile,'w') do |f|
      f << path
    end
  end

  def get_stored_path
    if (File.readable?(OBMtranslation::Config::ConfigFile))
      return File.open(OBMtranslation::Config::ConfigFile,'r').gets
    end
  end

  def quit
    Gtk.main_quit
  end

end



def HowLongDoesItTakesTo?
  t = Time.now
  yield
  STDOUT.print "#{Time.now - t}\n"
end


client = Main.instance
trap('INT') { client.quit }
client.build_gui
unless ARGV[0].nil? then
  path, lang, file = OBMtranslation::Dictionnary.explode_path(ARGV[0])
  client.set_lang(lang)
  client.set_path(path)
end
client.start

