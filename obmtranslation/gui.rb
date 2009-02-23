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



require 'libglade2'



module OBMtranslation
  module GUI



    class MainWindow
      include Singleton
      attr_reader :view, :path_chooser

      def initialize
        Gtk.init
        build_gui(Main.instance.dictionnary)
      end

      def set_lang_list(lang_list)
        @lang_list = lang_list
        @lang_group = []
        @lang_list.each do |lang_name|
          item = LangMenuItem.new(@lang_group,lang_name)
          @lang_group << item
          @lang_menu.append(item)
        end
        @lang_menu.show_all
      end

      def set_current_lang(name)
        if @view.set_lang(name) then
          menu_item = @lang_group.find{ |item| item.lang==name }
          menu_item.set_active(true) unless menu_item.active?
          update_title
        end
      end

      def show_window
        @window.show_all
      end

      def show_message_box(title="",text="",secondary_text="")
        @message_box.title = title
        @primary_text.text = text
        @secondary_text.text = secondary_text
        @message_box.show_all
      end

      def set_message_box_text(text)
        @primary_text.text = text
        @message_box.show_all
      end

      def set_message_box_secondary_text(secondary_text)
        @secondary_text.text = secondary_text
        @message_box.show_all
      end

      def hide_message_box
        @message_box.hide
      end

      def open_editor(lang,variable,ref,trans)
        @ref_lang_label.set_text(Config::RefLang)
        @ref_value.buffer.set_text(ref)
        @trans_lang_label.set_text(lang)
        @trans_value.buffer.set_text(trans)
        @popup.set_title(variable)
        @popup.show_all
      end

      def start_search
        @search_field.grab_focus
      end

    private

      def build_gui(dictionnary)
        glade = GladeXML.new(Config::GladeFile) { |handler| method(handler) }

        @message_box = glade['message_box']
        @primary_text = glade['primary_text']
        @secondary_text = glade['secondary_text']
        @path_chooser = DictionnaryChooser.new(glade['path_dialog'], glade['path_chooser'], glade['set_path_button'])
        glade['quit_button'].signal_connect('clicked') { Main.instance.quit }

        @popup = glade['edit_dialog']
        @ref_lang_label   = glade['ref_lang']
        @ref_value        = glade['ref_value']
        @trans_lang_label = glade['trans_lang']
        @trans_value      = glade['trans_value']
        @ok_button        = glade['ok_button']
        @cancel_button    = glade['cancel_button']
        @ok_button.signal_connect('clicked') { |button|
          @view.update_current_row(@trans_value.buffer.text)
          @popup.hide
        }
        @cancel_button.signal_connect('clicked') { |button|
          @popup.hide
        }

        @window = glade['window']
        @window.signal_connect('delete_event') { Main.instance.quit }
        glade['quit_item'].signal_connect('activate') { Main.instance.quit }
        glade['save_item'].signal_connect('activate') { Main.instance.save_changes }
        @lang_menu = glade['lang_menu']

        @view = View.new(glade['translation_view'], dictionnary)
        @search_field = glade['search_field']
        glade['search_button'].signal_connect('clicked') {
          @search_field.grab_focus
          @view.set_filter(@search_field.text)
        }
        glade['clean_button'].signal_connect('clicked') {
          @search_field.text=""
          @search_field.grab_focus
          @view.set_filter(nil)
        }
        glade['expandall_item'].signal_connect('activate') { @view.expand_all }
        glade['collapseall_item'].signal_connect('activate') { @view.collapse_all }
        glade['showfiles_item'].signal_connect('activate') { @view.toggle_view_files }

        @saveObserver = DictionnaryObserver.new(dictionnary)
      end

      def update_title
        @window.set_title("#{AppName} - #{Config::RefLang} 2 #{@view.lang or ''}")
      end

    end



    class DictionnaryChooser
      attr :dialog, :field

      def initialize(dialog, field, button)
        @dialog, @field = dialog, field
        button.signal_connect('clicked') { |button|
          path, lang = OBMtranslation::Dictionnary.explode_path(@field.current_folder)
          Main.instance.set_lang(lang)
          hide
          MainWindow.instance.show_window
          Thread.new { Main.instance.open_dictionnary(path) }
        }
        @dialog.signal_connect('delete_event') { Main.instance.quit }
      end

      def show(path=nil)
        @field.current_folder = path unless path.nil?
        @dialog.show_all
      end

      def hide
        @dialog.hide
      end
      
    end



    class View
      attr_reader :lang, :var_list, :view_files, :filter
      attr        :dico, :tree_view
      ColName, ColRef, ColTrans, ColVar, ColBG, ColFW = (0..5).to_a

      def initialize(tree_view, dictionnary)
        @tree_view = tree_view
        @dico = dictionnary
        @view_files = true
        @filter = ''
        @var_list = Gtk::TreeStore.new(String, String, String, Variable, Gdk::Color, Integer)
        @filtered_list = Gtk::TreeModelFilter.new(@var_list)
        @filtered_list.set_visible_func do |model, iter| 
          if @filter.empty? then
            true
          elsif @view_files and @var_list.iter_depth(iter)==0 then
            @view_files
          else
            data = (iter[ColName] or '')+(iter[ColRef] or '')+(iter[ColTrans] or '')
            data.downcase.include?(@filter)
          end
        end
        renderer_var = CellRendererTranslator.new(8,nil,true)
        renderer_lang1 = CellRendererTranslator.new(8,300)
        renderer_lang2 = CellRendererTranslator.new(8)
        #renderer_lang2.set_editable(true)
        @col_var = Gtk::TreeViewColumn.new("Variable", renderer_var, :text => ColName, :cell_background_gdk => ColBG, :weight => ColFW)
        @col_lang1 = Gtk::TreeViewColumn.new(Config::RefLang, renderer_lang1, :text => ColRef, :cell_background_gdk => ColBG).set_resizable(true)
        @col_lang2 = Gtk::TreeViewColumn.new("Lang", renderer_lang2, :text => ColTrans, :cell_background_gdk => ColBG).set_resizable(true)
        @tree_view.set_model(@filtered_list)
        @tree_view.append_column(@col_var)
        @tree_view.append_column(@col_lang1)
        @tree_view.append_column(@col_lang2)
        @tree_view.expander_column=@col_var
        @tree_view.signal_connect("row-activated") { |view, path, column|
          iter = @var_list.get_iter(path)
          if @var_list.iter_depth(iter)==0 then
            if @tree_view.row_expanded?(path) then
              @tree_view.collapse_row(path)
            else
              @tree_view.expand_row(path,true)
            end
          else
            set_current_row(path)
            variable, ref, trans, *properties = get_current_row
            MainWindow.instance.open_editor(@lang, variable, ref, trans)
          end
        }
        @tree_view.signal_connect("start-interactive-search") { |view|
          MainWindow.instance.start_search
        }
      end

      def expand_all
        if @view_files then
          @tree_view.expand_all
        end
      end

      def collapse_all
        if @view_files then
          @tree_view.collapse_all
        end
      end

      def set_lang(lang)
        if @dico.lang_list.member?(lang) then
          @lang = lang
          @col_lang2.set_title(lang)
          rebuild
          return true
        end #else
        false
      end

      def get_row(path)
        iter = var_list.get_iter(path)
        return iter[ColName], iter[ColRef], iter[ColTrans], iter[ColVar], iter[ColBG], iter[ColFW]
      end

      def update_row(path,value)
        t = @var_list.get_iter(path)
        t[ColVar].value = value
        t[ColTrans] = value
        t[ColBG] = (value.nil? or value=="") ? Config::RedColor : nil
      end

      def get_current_row
        get_row(@current_path)
      end

      def set_current_row(path)
        @current_path = path
      end

      def update_current_row(value)
        update_row(@current_path,value)
      end

      def toggle_view_files
        @view_files = !@view_files
        rebuild
      end

      def set_filter(str)
        @filter=(str or '').downcase
        @filtered_list.refilter
        @tree_view.expand_all
      end

    private

      def rebuild
        unless @lang.nil? then
          @var_list.clear
          @dico.ref_lang.files.each { |file_name,file|
            trans_file = @dico.lang[@lang].files[file_name]
            if @view_files then
              fiter = @var_list.append(nil)
              fiter[ColName] = file_name
              fiter[ColFW] = Pango::WEIGHT_BOLD
            else
              fiter = nil
            end
            file.variables.each { |var_name,ref_var|
              if trans_file.variables[var_name].nil? then
                trans_file.variables[var_name] = OBMtranslation::Variable.new(var_name,ref_var.vartype)
              end
              trans_var = trans_file.variables[var_name]
              iter = @var_list.append(fiter)
              iter[ColName]  = "#{var_name}"
              iter[ColRef]   = "#{ref_var.value}"
              iter[ColTrans] = "#{trans_var.value}"
              iter[ColVar]   = trans_var
              iter[ColBG]    = trans_var.empty? ? Config::RedColor : nil
              iter[ColFW]    = Pango::WEIGHT_NORMAL
            }
          }
          @filtered_list.refilter
          @tree_view.expand_all
          #expand_row
          #scroll_to_cell
        end
      end

    end



    class DictionnaryObserver < OBMtObserver

      def on_dictionnary_loading(dictionnary)
        MainWindow.instance.show_message_box("Chargement en cours...", "Lecture des fichiers de langue en cours...")
      end

      def on_dictionnary_loading_error(dictionnary)
        MainWindow.instance.hide_message_box
        #TODO manage dictionnary loading error
      end

      def on_dictionnary_loaded(dictionnary)
        MainWindow.instance.hide_message_box
        dictionnary.lang.each do |name,lang|
          observe(lang)
          lang.files.each do |filename,file|
            observe(file)
          end
        end
      end

      def on_dictionnary_saving(dictionnary)
        MainWindow.instance.show_message_box("Sauvegarde en cours...","Ecriture des fichiers en cours...")
      end

      def on_dictionnary_saving_error(dictionnary)
        MainWindow.instance.hide_message_box
        #TODO manage dictionnary saving error
      end

      def on_dictionnary_saved(dictionnary)
        MainWindow.instance.hide_message_box
      end

      def on_language_saving(language)
        MainWindow.instance.set_message_box_text("Sauvegarde de la langue \"#{language.name}\"...")
      end

      def on_language_saved(language)
        
      end

      def on_file_saving(file)
        MainWindow.instance.set_message_box_secondary_text("Ecriture du fichier \"#{file.filename}\"...")
      end

      def on_file_saved(file)
        
      end

      def on_file_saving_error(file)
        
      end

    end



    class LangMenuItem < Gtk::RadioMenuItem
      attr_reader :lang

      def initialize(group,lang)
        super(group,lang,false)
        @lang = lang
        signal_connect('toggled') { |item|
          MainWindow.instance.set_current_lang(@lang) if item.active? and MainWindow.instance.view.lang!=(@lang)
        }
      end

    end



    class CellRendererTranslator < Gtk::CellRendererText

      def initialize(text_size=nil, width=nil, strong=false)
        super()
        set_size_points(text_size)     unless text_size.nil?
        set_width(width)               unless width.nil?
        set_weight_set(strong)
      end
      
    end

  end
end

