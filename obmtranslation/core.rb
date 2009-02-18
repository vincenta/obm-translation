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



require 'gtk2'
require 'fileutils'
require 'date'
require 'singleton'
require 'observer'



module OBMtranslation

  AppName = 'OBMtranslation'
  Version = '0.5'

  Special   = 0
  ShortText = 1
#  LongText  = 2

  VarRegExp     = /^(\$[^\s=]+)\s*=\s*(.*)\s*;/m
  IsString      = /^(["'])(([^\\]|\\.)*)\1$/m
  IncString     = /(["'])(([^\\]|\\.)*)\1/m
  IncCommentary = /(\/\*((?!\*\/).)*\*\/)|(\/\/[^\n]*\n)/m
  MacGiver      = /("([^\\"]|\\.)*"|'([^\\']|\\.)*'|[^"'])*;\s*/m



  # override this function to encode strings to the specified encoding
  def OBMtranslation.encode(s)
    s
  end

  # override this function to decode strings from the specified encoding
  def OBMtranslation.decode(s)
    s
  end



  module OBMtObservable
    include Observable

  private

    def notify(event,*args)
      changed
      Thread.new {
        notify_observers(event,*args)
      }
    end

  end



  class OBMtObserver

    def initialize(observable_object)
      observable_object.add_observer(self)
    end

    def observe(observable_object)
      observable_object.add_observer(self)
    end

    def update(handler,*args)
      if respond_to?(handler) then
        method(handler).call(*args)
      end
    end

  end



  class Dictionnary
    include OBMtObservable
    attr_reader :path, :lang

    def Dictionnary.dictionnary_folder?(path)
      p = File.expand_path(path)
      File.directory?(p) && File.basename(p)==="lang"
    end

    def Dictionnary.lang_folder?(path)
      p = File.expand_path(path)
      File.directory?(p) && File.basename(File.dirname(p))==="lang"
    end

    def Dictionnary.lang_file?(path)
      file = basename(path)
      p = File.dirname(File.expand_path(path))
      File.file?(p) && File.basename(File.dirname(p))==="lang"
    end

    def Dictionnary.explode_path(path) # return sample : "/path/to/lang", "fr", "calendar.inc"
      p = File.expand_path(path)
      if /.inc$/=~p then
        file = File.basename(p)
        p = File.dirname(p)
      end
      if File.basename(p)!="lang" && p!="/" then
        return File.dirname(p), File.basename(p), file
      else
        return p, nil, nil
      end
    end

    def initialize(ref_lang)
      @ref_lang_name = ref_lang
      @path = nil
      @lang = nil
    end

    def load(path)
      notify("on_dictionnary_loading",self)
      @path = path
      @lang = { @ref_lang_name => ReferenceLanguage.new(@path,@ref_lang_name) }
      Dir.open(@path) do |dir|
        dir.each do |d|
          add_lang(d) if File.directory?("#{@path}/#{d}") && d!=@ref_lang_name && !(/^\./=~d)
        end
      end
      notify("on_dictionnary_loaded",self)
    rescue => e
      notify("on_dictionnary_loading_error",self)
    end

    def save_changes
      notify("on_dictionnary_saving",self)
      @lang.each do |name,lang|
        lang.save_changes
      end
      notify("on_dictionnary_saved",self)
    rescue => e
      notify("on_dictionnary_saving_error",self)
    end

    def ref_lang
      @lang[@ref_lang_name]
    end

    def lang_list
      @lang.keys.sort
    end

    def file_list
      @lang[@ref_lang_name].files.keys
    end

  private

    def add_lang(name)
      if (!(/\//===name) && name!="." && name!=".." && @lang[name].nil?) then
        @lang[name] = Language.new(@path,name,file_list)
      end
    end

  end



  class Language
    include OBMtObservable
    attr_reader :name, :files

    def initialize(path,name,file_list)
      @name = name
      @files = {}
      @path = "#{path}/#{@name}"
      FileUtils.mkdir_p(@path) unless File.exist?(@path)
      file_list.each do |name|
        add_file(name)
      end
    end

    def add_file(name)
      if (!(/\//===name) && /.*\.inc$/ === name && @files[name].nil?) then
        @files[name] = LanguageFile.new(name,@path)
      end
    end

    def save_changes
      notify("on_language_saving",self)
      @files.each do |name,file|
        file.save_changes
      end
      notify("on_language_saved",self)
    end

  end



  class ReferenceLanguage < Language

    def initialize(path,name)
      @name = name
      @files = {}
      @path = "#{path}/#{@name}"
      FileUtils.mkdir_p(@path) unless File.exist?(@path)
      d = Dir.open(@path)
      d.each do |f|
        add_file(f)
      end
    end

  end



  class LanguageFile
    include OBMtObservable
    attr_reader :filename, :parser, :variables

    def initialize(filename, path)
      @filename = filename
      @variables = {}
      @parser = Parser.new(filename, path)
      @parser.each do |variable|
        @variables[variable.name] = variable
      end
    end

    def changes
      @variables.values.select do |var|
        var.modified?
      end
    end

    def modified?
      changes.any?
    end

    def save_changes
      notify("on_file_saving",self)
      modifications = changes
      if modifications.any? then
        @parser.write(modifications)
        forget_changes(modifications)
      end
      notify("on_file_saved",self)
    rescue => e
      notify("on_file_saving_error",self)
    end

  private

    def forget_changes(modified_vars)
      modified_vars.each do |var|
        var.modified=false
      end
    end

  end



  # to read/write variables from a language file
  class Parser
    attr_reader :filename, :file

    def initialize(filename, path)
      @filename = filename
      @file = "#{path}/#{filename}"
    end

    def each(&action)
      if File.exists?(@file) then
        OBMTFile.open(@file,"r") do |f|
          f.each_obmt_entry do |entry|
            var = parse(entry)
            action.call(var) unless var.nil?
          end
        end
      end
    end

    def write(changes)
      OBMTFile.create(@file) unless File.exist?(@file)
      FileUtils.cp(@file,"#{@file}~")
      OBMTFile.open("#{@file}~","r") do |fsrc|
        OBMTFile.open(@file,"w") do |fdest|
          now = DateTime.now.to_s
          fdest << OBMtranslation.encode(fsrc.read_header||OBMTFile.new_header(@filename))
          fdest << "// Modified on #{now} using #{AppName} (#{Version})\n\n"
          fsrc.each_obmt_entry do |entry|
            var = parse(entry)
            entry = entry+"\n"
            if (modified = changes.find { |v| v.name==var.name }) then
              entry = modified.to_s
              changes.delete_if { |v| v.name==var.name }
            end
            fdest << OBMtranslation.encode(entry)
          end
          fdest << "\n// lines below have been created with #{AppName} (#{Version}) on #{now}\n" if changes.any?
          changes.each do |var|
            fdest << OBMtranslation.encode(var.to_s)
          end
          fdest << "\n"
        end
      end
      FileUtils.rm("#{@file}~")
    end

  private

    def parse(block)
      block.gsub!(IncCommentary,'')
      unless block.nil? then 
        block.strip!
        Variable.parse(block)
      end
    end

  end



  class OBMTFile < File

    def OBMTFile.create(fullpath)
      filename = File.basename(fullpath)
      open(fullpath,'w',0644) do |f|
        f << OBMTFile.new_header(filename).to_s
      end
    end

    def OBMTFile.new_header(filename)
      s = "<script language=\"php\">\n"
      s << "/"*80 << "\n"
      s << "// OBM - Language : ".ljust(78) << "//\n"
      s << "//     - File     : #{filename}".ljust(78) << "//\n"
      s << "// #{Date.today.to_s}".ljust(78) << "//\n"
      s << "/"*80 << "\n"
      s
    end

    def each_obmt_entry(&action)
      skip_header
      block = ""
      each(';') do |line|
        block += OBMtranslation.decode(line + (gets||''))
        if block_ended?(block) then
          action.call(block)
          block=""
        end
      end
    end

    def skip_header
      if pos==0 or lineno==0 then
        line = OBMtranslation.decode(gets)
        while (line = OBMtranslation.decode(gets)) and line =~ /^\/\// do end
      end
    end

    def read_header
      seek(0)
      lineno = 0
      head = OBMtranslation.decode(gets)
      while (line = OBMtranslation.decode(gets)) and line =~ /^\/\// do
        head += line
      end
      head
    end

    def header
      current_pos,current_lineno = pos,lineno
      seek(0)
      head = OBMtranslation.decode(gets)
      while (line = OBMtranslation.decode(gets)) and line =~ /^\/\// do
        head += line
      end
      seek(remember_pos)
      lineno = remember_lineno
      head
    end

  private

    def block_ended?(block)
      tmp = block.gsub(IncCommentary,'')
      tmp =~ MacGiver
    end

  end



  # describes a variable
  class Variable
    attr_reader   :name, :vartype
    attr_accessor :value, :modified

    def Variable.parse(string)
      var = VarRegExp.match(string)
      unless var.nil? then
        name, val = var[1], var[2].strip
        case val
          when IsString
            t = IsString.match(val)
            Variable.new(name, ShortText, t[2], false)
          else
            Variable.new(name, Special, val, false)
        end
      end
    end

    def initialize(name, vartype, value=nil, modified=true)
      @name, @vartype, @value, @modified = name, vartype, value, modified
    end

    def empty?
      @value=="" or value.nil?
    end

    def modified?
      @modified
    end

    def value=(value)
      @modified = true
      @value = value
    end

    def include?(str)
      (!@value.nil? && @value.downcase.include?(str))
    end

    def multiline?
      @value.include?("\n") unless @value.nil?
    end

    def to_s
      comment = ""
      prefix = multiline? ? "\n" : ""
      if @vartype==Special then
        "#{@name} = #{prefix}#{@value}; #{comment}\n"
      else
        "#{@name} = #{prefix}\"#{(@value||"").gsub('"', '\"')}\"; #{comment}\n"
      end
    end

  end

end

