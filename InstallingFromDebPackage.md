#How to Install on Debian (or Ubuntu) GNU/Linux ?

# How to Install on Debian (or Ubuntu) GNU/Linux ? #

OBM Translation depends on ruby and ruby-gnome2 packages. So, you have to install these packages and all the dependencies (using apt or aptitude).
_e.g. (as root) :_
```
aptitude update
aptitude install ruby ruby-gnome2
```

Download the latest debian package from the [download page](http://code.google.com/p/obm-translation/downloads/list), and install it !
_e.g. (as root) :_
```
cd /tmp/
wget http://obm-translation.googlecode.com/files/obmtranslation-0.5a.deb
dpkg -i obmtranslation-0.5a.deb
```

Then, you can launch OBM Translation using the obmtranslation command.
_e.g. (as normal user) :_
```
obmtranslation
```
_or_
```
obmtranslation path/to/obm/obminclude/lang/en
```