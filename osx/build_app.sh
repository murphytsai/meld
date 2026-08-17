#!/bin/bash -x

set -o nounset
set -o errexit
set -o functrace

trap "exit" INT
failure() {
  local lineno=$1
  local msg=$2
  echo "Failed at $lineno: $msg"
}
trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

export PATH=$HOME/.new_local/bin:$HOME/gtk/inst/bin:$PATH

APP="$PWD/dist/Meld.app"
MAIN="$APP/"
RES="$MAIN/Contents/Resources/"
FRAMEWORKS="$MAIN/Contents/Frameworks/"
INSTROOT="$HOME/gtk/inst/"
CODE_SIGN_ID=""
INSTALLER_CODE_SIGN_ID=""


# TODO: Move this to build_env.sh
#icon_sizes=( "16" "22" "24" "32" "48" "64" "72" "96" "128" "256" "512"  )
#for icon_size in ${icon_sizes[@]}; do
#  rm -f ${INSTROOT}/share/icons/hicolor/${icon_size}x${icon_size}/apps/org.gnome.Meld.png
#  inkscape -z -w ${icon_size} -h ${icon_size} data/icons/hicolor/scalable/apps/org.gnome.meld.svg \
#    -o ${INSTROOT}/share/icons/hicolor/${icon_size}x${icon_size}/apps/org.gnome.Meld.png
#done;
#(cd ${INSTROOT}/share/icons/hicolor/ && gtk-update-icon-cache -fqt .)
# intltool

cp meld/conf.py.in meld/conf.py.in.orig
cp osx/conf.py meld/conf.py

${INSTROOT}/bin/python3 -c "import sys; print('\n'.join(sys.path))"

PY_SITE_PACKAGES=$(~/gtk/inst/bin/python3 -c 'import site; print(site.getsitepackages()[0], end="")')
BREW_PREFIX="$(brew --prefix)"
"$BREW_PREFIX/bin/pip3" install --upgrade --force-reinstall distro pyobjc-core pyobjc-framework-Cocoa py2app six pygments --target $PY_SITE_PACKAGES

glib-compile-schemas data
${INSTROOT}/bin/python3 setup_py2app.py build
${INSTROOT}/bin/python3 setup_py2app.py py2app --use-faulthandler

mv meld/conf.py.in.orig meld/conf.py.in
rm meld/conf.py

# icon themes
rsync -r -t --ignore-existing ${INSTROOT}/share/icons/Meld-WhiteSur-Icons ${RES}/share/icons
rsync -r -t --ignore-existing ${INSTROOT}/share/icons/hicolor ${RES}/share/icons
(cd ${RES}/share/icons && ln -sf Meld-WhiteSur-Icons MeldIcons)

# glib schemas
rsync -r -t  $INSTROOT/share/glib-2.0/schemas $RES/share/glib-2.0
cp data/org.gnome.meld.gschema.xml $RES/share/glib-2.0/schemas
(cd $RES/share/glib-2.0 && glib-compile-schemas schemas)
rsync -r -t  $INSTROOT/share/GConf/gsettings $RES/share/GConf

# pango
# mkdir -p $RES/etc/pango
# pango-querymodules |perl -i -pe 's/^[^#].*\///' > $RES/etc/pango/pango.modules
# echo "[Pango]\nModuleFiles=./etc/pango/pango.modules\n" > $RES/etc/pango/pangorc

# gdk-pixbuf
rsync -r -t $INSTROOT/lib/gdk-pixbuf-2.0 $RES/lib
gdk-pixbuf-query-loaders  | sed s=\".*/lib/gdk-pixbuf-2.0=\"@executable_path/\.\./Resources/lib/gdk-pixbuf-2.0=  > $RES/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
(cd $MAIN/Contents && ln -sf Resources/lib .)

# GTK themes
mkdir -p $RES/share/themes
rsync -r -t $INSTROOT/share/themes/Default/ $RES/share/themes/Default
rsync -r -t $INSTROOT/share/themes/Mac/ $RES/share/themes/Mac
rsync -r -t $INSTROOT/share/themes/WhiteSur-Dark-solid/ $RES/share/themes/WhiteSur-Dark-solid
rsync -r -t $INSTROOT/share/themes/WhiteSur-Light-solid/ $RES/share/themes/WhiteSur-Light-solid
rsync -r -t $INSTROOT/share/gtksourceview-4 $RES/share
cp $INSTROOT/share/themes/Mac/gtk-3.0/gtk-keys.css $RES/share/themes/WhiteSur-Light-solid/gtk-3.0/gtk-keys.css
cp $INSTROOT/share/themes/Mac/gtk-3.0/gtk-keys.css $RES/share/themes/WhiteSur-Dark-solid/gtk-3.0/gtk-keys.css

# meld specific resources
mkdir -p $RES/share/meld
rsync -r -t data/icons/* $RES/share/icons
### rsync -r -t data/meld.css $RES/share/meld
### rsync -r -t data/styles/meld-dark.xml $RES/share/gtksourceview-4/styles
### rsync -r -t data/styles/meld-base.xml $RES/share/gtksourceview-4/styles

# update icon cache for Adwaita
# We now trinm Adwaita instead..
# rm -fr $RES/share/icons/Adwaita/cursors
# rm -fr $RES/share/icons/Adwaita/256x256
# rm -fr $RES/share/icons/Adwaita/512x512
# icon_sizes=( "16" "22" "24" "32" "48" "64" "72" "96" "128"  )
# for icon_size in ${icon_sizes[@]}; do
#   rm -fr ${RES}/share/icons/Adwaita/${icon_size}x${icon_size}/apps/   || true
#   rm -fr ${RES}/share/icons/Adwaita/${icon_size}x${icon_size}/legacy/ || true
#   rm -fr ${RES}/share/icons/Adwaita/${icon_size}x${icon_size}/emotes/ || true
#   rm -fr ${RES}/share/icons/Adwaita/${icon_size}x${icon_size}/categories/ || true
#   rm -fr ${RES}/share/icons/Adwaita/${icon_size}x${icon_size}/status/ || true
# done;
# (cd $RES/share/icons/Adwaita && gtk-update-icon-cache -fqt .)

# update icon cache for hicolor
(cd $RES/share/icons/hicolor && gtk-update-icon-cache -fqt .)
(cd $RES/share/icons/MeldIcons && gtk-update-icon-cache -fqt .)

# copy fontconfig configuration files
(cd $INSTROOT/etc/fonts/conf.d && ln -sf ../../../share/fontconfig/conf.avail/10-autohint.conf .)
mkdir -p $RES/etc/fontconfig/conf.d
[ -f $INSTROOT/etc/fonts/fonts.conf ] && cp $INSTROOT/etc/fonts/fonts.conf $RES/etc/fontconfig
for i in $(find $INSTROOT/etc/fonts/conf.d); do
  cp $INSTROOT/share/fontconfig/conf.avail/$(basename $i) $RES/etc/fontconfig/conf.d || true
done

# copy main libraries
mkdir -p $RES/lib
rsync -r -t $INSTROOT/lib/gtk-3.0 $RES/lib
rsync -r -t $INSTROOT/lib/girepository-1.0 $RES/lib
rsync -r -t $INSTROOT/lib/gobject-introspection $RES/lib

# copy some libraries that py2app misses
mkdir -p $FRAMEWORKS
rsync -t $INSTROOT/lib/*.dylib $FRAMEWORKS/

# rename script, use wrapper
#mv $MAIN/Contents/MacOS/Meld $MAIN/Contents/MacOS/Meld-bin
#rsync -t osx/meld.applescript $MAIN/Contents/MacOS/meld_wrapper
#mv $MAIN/Contents/MacOS/meld_wrapper $MAIN/Contents/MacOS/Meld
chmod +x $MAIN/Contents/MacOS/Meld
(cd $RES/share/meld && ln -sf org.gnome.meld.gresource meld.gresource)
#chmod +x $MAIN/Contents/MacOS/Meld-bin

# unroot the library path
pushd .
cd $MAIN/Contents/
# Original from
# https://github.com/apocalyptech/eschalon_utils/blob/master/make-osx-apps.sh
#
# Modify library paths in the modules manually with install_name_tool
# Modified from tegaki create_app_bundle.sh
# Keep looping as long as we added more libraries
newlibs=1
while [ $newlibs -gt 0 ]; do
  newlibs=0
  for dylib in $(find . -name "*.so" -o -name "*.dylib"); do
    echo "Modifying library references in $dylib"
    changes=""
    for lib in `otool -L $dylib | egrep "($INSTROOT|libs/)" | awk '{print $1}'` ; do
      base=`basename $lib`
      changes="$changes -change $lib @executable_path/../Frameworks/$base"
      # Copy the library in if necessary
      if [ ! -f "$FRAMEWORKS/$base" ]; then
        echo "Copying in $lib"
        cp $lib $FRAMEWORKS
        # Loop again so we can pick up this library's dependencies
        newlibs=1
      fi
    done
    if test "x$changes" != x ; then
      if ! install_name_tool $changes $dylib ; then
        echo "Error for $dylib"
      fi
      install_name_tool -id @executable_path/../$dylib $dylib
    fi
  done
done

WORKDIR=$(mktemp -d)
for i in $(find $HOME/gtk/inst/share/gir-1.0 -name *.gir); do
    gir=$(echo $(basename $i))
    typelib=${gir%.*}.typelib
    echo Processing $gir to ${WORKDIR}/$typelib

    cat $i | sed s_"$HOME/gtk/inst/lib"_"@executable\_path/../Frameworks"_g > ${WORKDIR}/$gir
    $HOME/gtk/inst/bin/g-ir-compiler ${WORKDIR}/$gir -o ${WORKDIR}/$typelib
done
cp ${WORKDIR}/*.typelib ${RES}/lib/girepository-1.0
rm -fr ${WORKDIR}


#for dylib in $(find . -name "*.dylib"); do
#  echo "Adding @executable_path/../Frameworks/$dylib to Meld"
#  install_name_tool -add_rpath "@executable_path/../Frameworks/$dylib" $MAIN/Contents/MacOS/Meld
#done
popd

# Patch __boot__.py to delete savedState folder
# Fixes issue

cat <<< "import os
import shutil
home_dir = os.path.expanduser('~')
if home_dir is not None:
    saved_state_dir = os.path.join(home_dir, 'Library', 'Saved Application State', 'org.gnome.meld.savedState')
    if os.path.isdir(saved_state_dir):
        try:
            shutil.rmtree(saved_state_dir, ignore_errors=1)
        except:
            pass

$(cat $MAIN/Contents/Resources/__boot__.py)" > $MAIN/Contents/Resources/__boot__.py

signed=0
if [ -z "${CODE_SIGN_ID}" ]; then
  echo "Not signing code - no identity provided."
  echo "   Set CODE_SIGN_ID to your 'Developer ID Application: xxxx' in order to sign the app."
else
  codesign --deep --signature-size 9400 -f -s "${CODE_SIGN_ID}" "${APP}"
  codesign --verify --deep --strict --verbose=2 "${APP}" && signed=1
fi

# Create the dmg file..
hdiutil create -size 250m -fs HFS+ -volname "Meld Merge" myimg.dmg
hdiutil attach myimg.dmg
DEVS=$(hdiutil attach myimg.dmg | cut -f 1)
DEV=$(echo ${DEVS} | cut -f 1 -d ' ')
rsync  -avzh  "${APP}" /Volumes/Meld\ Merge/
pushd .
(cd /Volumes/Meld\ Merge/ && ln -sf /Applications "Drag Meld Here")
popd

# Compress the dmg file..
cp osx/DS_Store /Volumes/Meld\ Merge/.DS_Store
sync
hdiutil detach $DEV
hdiutil convert myimg.dmg -format UDZO -o meldmerge.dmg

#dmg_signed=0
if [ -z "${INSTALLER_CODE_SIGN_ID}" ]; then
  echo "Not signing dmg - no identity provided."
  echo "   Set INSTALLER_CODE_SIGN_ID to your 'Developer IDxx' in order to sign the dmg."
else
  codesign --deep --signature-size 9400 -f -s "${INSTALLER_CODE_SIGN_ID}" "meldmerge.dmg"
  #spctl -a -t exec -vv "meldmerge.dmg" && dmg_signed=1
fi


# Cleanup
mkdir -p osx/Archives
mv meldmerge.dmg osx/Archives
rm -f myimg.dmg
rm -fr build
rm -fr dist
open osx/Archives

if (( $signed == 1 )); then
  echo "Built application was signed."
else
  echo "Built application was NOT signed."
fi
