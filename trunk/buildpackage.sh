#!/bin/bash
version=0.5a
mv -f obmtranslation/config.rb obmtranslation/config.rb.bak
sed "s/DataDir\ =\ '.*'/DataDir\ =\ '\/usr\/share\/obmtranslation'/" obmtranslation/config.rb.bak > obmtranslation/config.rb
sudo epm -n -f deb obmtranslation
rm -f obmtranslation/config.rb
mv -f obmtranslation/config.rb.bak obmtranslation/config.rb
tar_dir=linux-2.6-intel/obmtranslation-$version
rm -Rf $tar_dir
mkdir $tar_dir
cp -f obmtranslation.rb $tar_dir
cp -Rf obmtranslation $tar_dir
cp -Rf glade $tar_dir
cp -f LICENSE $tar_dir
sed s/DataDir\ =\ '.*'/DataDir\ =\ \'\.\'/ obmtranslation/config.rb > $tar_dir/obmtranslation/config.rb
cd linux-2.6-intel
tar -czf obmtranslation-$version.tgz obmtranslation-$version
cd ..
rm -Rf $tar_dir
