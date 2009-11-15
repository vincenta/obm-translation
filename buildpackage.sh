#!/bin/bash
majorversion="0.5.1"
revision=`svnversion`
version="$majorversion-$revision"
builddir="linux-2.6-all"

mv -f obmtranslation/core.rb obmtranslation/core.rb.bak
sed "s/Version\ =\ '.*'/Version\ =\ '$majorversion'/" obmtranslation/core.rb.bak > obmtranslation/core.rb

mv -f obmtranslation/config.rb obmtranslation/config.rb.bak
sed "s/DataDir\ =\ '.*'/DataDir\ =\ '\/usr\/share\/obmtranslation'/" obmtranslation/config.rb.bak > obmtranslation/config.rb

sed "s/%version\ .*/%version $version/" obmtranslation.list.dist > obmtranslation.list

sudo epm -a all -n -f deb obmtranslation

rm -f obmtranslation/core.rb.bak
rm -f obmtranslation/config.rb
mv -f obmtranslation/config.rb.bak obmtranslation/config.rb
rm -f obmtranslation.list

tar_dir="$builddir/obmtranslation-$version"
rm -Rf $tar_dir
mkdir $tar_dir
cp -f obmtranslation.rb $tar_dir
cp -Rf obmtranslation $tar_dir
cp -Rf glade $tar_dir
cp -f LICENSE $tar_dir
sed s/DataDir\ =\ '.*'/DataDir\ =\ \'\.\'/ obmtranslation/config.rb > $tar_dir/obmtranslation/config.rb
cd $builddir
tar -czf obmtranslation-$version.tgz obmtranslation-$version
cd ..
rm -Rf $tar_dir
