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



module OBMtranslation
  module Config

# do not modify below unless you know what you are doing

    # the OBM lang files encoding :
    # - iso-8859-1 or iso-8859-15 if OBM < 2.2
    # - utf-8                     if OBM >= 2.2
    Charset = 'utf-8'

    # default opened language
    DefLang = 'en'

    # reference language used to translate
    RefLang = 'fr'

    # color used to notify untranslated variable
    RedColor = Gdk::Color.new(65535, 32767, 32767)

    # the path to the OBM-Translation data directory
    DataDir = '.'

    # path to the GUI glade file
    GladeFile = File.join(DataDir, 'glade', 'obmtranslation.glade')

    # path to the current user OBM-Translation config file
    ConfigFile = File.join(ENV['HOME'],'.obmtranslation')

  end

  if (Config::Charset=='utf-8') then
    $KCODE='u'
  else
    def OBMtranslation.encode(s)
      if s then
        GLib.convert(s, Config::Charset, "utf-8")
      end
    end
    def OBMtranslation.decode(s)
      if s then
        GLib.convert(s, "utf-8", Config::Charset)
      end
    end
  end

end

