#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

trap "exit" INT
failure() {
  local lineno=$1
  local msg=$2
  echo "Failed at $lineno: $msg"
}
trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

export CC=/usr/bin/clang
export CXX=/usr/bin/clang++
export CCACHE_DISABLE=1

export PATH=$HOME/.new_local/bin:$HOME/gtk/inst/bin:$PATH

mkdir -p $HOME/gtk/inst/bin

BREW_PREFIX="$(brew --prefix)"
ln -sf "$BREW_PREFIX/bin/autoconf" ~/gtk/inst/bin
ln -sf "$BREW_PREFIX/bin/autoreconf" ~/gtk/inst/bin
ln -sf "$BREW_PREFIX/bin/automake" ~/gtk/inst/bin
ln -sf "$BREW_PREFIX/bin/autopoint" ~/gtk/inst/bin
ln -sf "$BREW_PREFIX/bin/pkg-config" ~/gtk/inst/bin
ln -sf "$BREW_PREFIX/bin/aclocal" ~/gtk/inst/bin
ln -sf "$BREW_PREFIX/bin/glibtoolize" ~/gtk/inst/bin/libtoolize 
ln -sf "$BREW_PREFIX/bin/glibtool" ~/gtk/inst/bin/libtool
ln -sf "$BREW_PREFIX/bin/cmake" ~/gtk/inst/bin
ln -sf "$BREW_PREFIX/opt/bison/bin/bison" ~/gtk/inst/bin
ln -sf "$BREW_PREFIX/bin/itstool" ~/gtk/inst/bin
ln -sf "$BREW_PREFIX/bin/xz" ~/gtk/inst/bin

pushd . > /dev/null

export PKG_CONFIG_PATH=$HOME/gtk/inst/lib/pkgconfig:$HOME/gtk/inst/share/pkgconfig
export PKG_CONFIG_LIBDIR=$HOME/gtk/inst/lib/pkgconfig
export XDG_DATA_DIRS=$HOME/gtk/inst/share

[ -d $HOME/gtk/inst/lib/gettext ] || \
(
	cd $HOME/Source
	rm -fr libiconv-1.17 libiconv-1.17.tar.gz || true
	curl -OL https://ftp.gnu.org/gnu/libiconv/libiconv-1.17.tar.gz
    tar xf libiconv-1.17.tar.gz
	cd libiconv-1.17
	jhbuild run ./configure	--disable-debug \
			   --disable-dependency-tracking \
			   --enable-extra-encodings \
			   --enable-static \
			   --disable-shared \
			   --prefix=$HOME/gtk/inst
	jhbuild run make -j8
	jhbuild run make install

	cd $HOME/Source/
	rm -fr gettext-0.22.3 gettext-0.22.3.tar.xz || true
	curl -OL https://ftp.gnu.org/gnu/gettext/gettext-0.22.3.tar.xz	
	tar xf gettext-0.22.3.tar.xz
	cd gettext-0.22.3
	jhbuild run ./configure --without-emacs \
			  --disable-silent-rules \
			  --disable-java \
			  --disable-native-java \
			  --disable-libasprintf \
			  --disable-csharp \
			  --with-included-glib \
			  --with-included-libcroco \
			  --with-included-gettext \
			  --with-included-libunistring \
			  --without-git \
			  --without-cvs \
			  --without-xz \
			  --prefix=$HOME/gtk/inst
	jhbuild run make -j8
	jhbuild run make install

	cd $HOME/Source/libiconv-1.17
)

# jhbuild bootstrap
jhbuild buildone libffi zlib
# For later - perhaps make python use this library instead. 
# (cd $HOME/Source/ && rm -fr tinygettext || true)
# (cd $HOME/Source/ && git clone https://github.com/tinygettext/tinygettext)
# (cd $HOME/Source/tinygettext/external && rm -fr tinycmmc)
# (cd $HOME/Source/tinygettext/external && git clone https://github.com/Grumbel/tinycmmc)
# (cd $HOME/Source/tinygettext && mkdir -p build && cd build && cmake .. && make -j8 && cmake --install . --prefix $HOME/gtk/inst)

# For now: stub gettext
# (
#   cd $HOME/Source/ 
#     rm -fr gettext-tiny || true
#     git clone https://github.com/sabotage-linux/gettext-tiny
#   cd $HOME/Source/gettext-tiny
#     #gsed -i 's=/usr/local=/=g' Makefile;
#     make LIBINTL=NOOP DESTDIR=$HOME/gtk/inst prefix=/ install 
# 	#DESTDIR=$HOME/gtk/inst make install
# )

jhbuild buildone python3



#PYTHON=$HOME/gtk/inst/bin/python3 PYTHON_CFLAGS=-I$HOME/gtk/inst/include/python3.11
jhbuild buildone libxml2
#(cd $HOME/gtk/inst/bin && touch itstool && chmod +x itstool)

PY_SITE_PACKAGES=$(~/gtk/inst/bin/python3 -c 'import site; print(site.getsitepackages()[0], end="")')
"$BREW_PREFIX/bin/pip3" install six pygments --target $PY_SITE_PACKAGES

# Build all the way up to freetype, then fix its pkg-config
PYTHON=$HOME/gtk/inst/bin/python3 jhbuild build freetype
gsed -i '/^Requires.private.*/d' $HOME/gtk/inst/lib/pkgconfig/freetype2.pc

# Continue
PYTHON=$HOME/gtk/inst/bin/python3 jhbuild build #-s freetype-no-harfbuzz
"$BREW_PREFIX/bin/pip3" install pyobjc-core pyobjc-framework-Cocoa py2app --target $PY_SITE_PACKAGES

cat $HOME/gtk/inst/lib/pkgconfig/epoxy.pc | grep -v x11 > $HOME/gtk/inst/lib/pkgconfig/epoxy.pc.1
mv $HOME/gtk/inst/lib/pkgconfig/epoxy.pc $HOME/gtk/inst/lib/pkgconfig/epoxy.pc.orig
mv $HOME/gtk/inst/lib/pkgconfig/epoxy.pc.1 $HOME/gtk/inst/lib/pkgconfig/epoxy.pc

jhbuild buildone gtksourceview3 gtk-mac-integration gtk-mac-integration-python

# (cd $HOME/gtk/inst/lib && ln -s libpython3.6m.dylib libpython3.6.dylib)
# (cd $HOME/Source/ && ([ -d Mojave-gtk-theme ] || git clone https://github.com/vinceliuice/Mojave-gtk-theme.git))
# (cd $HOME/Source/Mojave-gtk-theme && sed -i.bak 's/cp -ur/cp -r/' install.sh && ./install.sh  --dest $HOME/gtk/inst/share/themes)
# (cd $HOME/gtk/inst/share/themes && ln -sf Mojave-dark-solid-alt Meld-Mojave-dark)
# (cd $HOME/gtk/inst/share/themes && ln -sf Mojave-light-solid-alt Meld-Mojave-light)

pushd .
# cd $HOME/Source
# GTKSRCVIEW=gtksourceview-4.8.4
# curl -OL https://download.gnome.org/sources/gtksourceview/4.8/gtksourceview-4.8.4.tar.xz
# tar xvf ${GTKSRCVIEW}.tar.xz 
# mkdir -p ${GTKSRCVIEW}/build && cd ${GTKSRCVIEW}/build
# jhbuild run meson setup --prefix=$HOME/gtk/inst --buildtype=release --optimization 3 -Dvapi=false $HOME/Source/${GTKSRCVIEW} # --Denable-introspection=yes --Denable-gtk-doc-html=no --with-sysroot=$HOME/gtk/inst
# jhbuild run ninja install
# popd

cp settings.ini $HOME/gtk/inst/etc/gtk-3.0/
popd


# Seems like the build system changed for introspection. We now get many
# gir files without the prefix/full path to the library.
# We want the prefixes. We'll edit them manually later in build_app to point
# to the ones we include. 
# Moving to fix-gir script..
# WORKDIR=$(mktemp -d)
# for i in $(find $HOME/gtk/inst/share/gir-1.0 -name *.gir); do
# 	if [ `grep shared-library=\"lib* ${i}` ]; then
#         gir=$(echo $(basename $i))

# 		typelib=${gir%.*}.typelib
# 		echo Processing $gir to ${WORKDIR}/$typelib

# 		cat $i | sed s_"shared-library=\""_"shared-library=\"$HOME/gtk/inst/lib/"_g > ${WORKDIR}/$gir
# 		cp ${WORKDIR}/$gir $HOME/gtk/inst/share/gir-1.0
# 		$HOME/gtk/inst/bin/g-ir-compiler ${WORKDIR}/$gir -o ${WORKDIR}/$typelib
# 	fi
# done
# cp ${WORKDIR}/*.typelib $HOME/gtk/inst/lib/girepository-1.0
# rm -fr ${WORKDIR}


exit
# At some point, I'd like to see how this would perform. pypy3 can already be used during development
# however, py2app isn't really setup to use it directly. I'll check it out when I get the time.

[ -f $HOME/gtk/inst/bin/pypy3 ] || {
	cd $HOME/Source && curl -O -L https://bitbucket.org/pypy/pypy/downloads/pypy3-v6.0.0-osx64.tar.bz2
	tar xf pypy3-v6.0.0-osx64.tar.bz2
	rsync -r $HOME/Source/pypy3-v6.0.0-osx64/* $HOME/gtk/inst
	cd  $HOME/gtk/inst/bin
	ln -s pypy3 python
	ln -s pypy3 python3
	./pypy3 -m ensurepip
	./pip3 install -U pip
	./pip3 install six
	touch itstool && chmod +x itstool		#dummy itstool to compile gtk-doc
}


