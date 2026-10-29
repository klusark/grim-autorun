mkdir -p /home/Joel/scummvm/build-opt && cd /home/Joel/scummvm/build-opt
if [ ! -f config.mk ]; then
	../configure --disable-all-engines --enable-engines=grim,monkey4 --enable-release 2>&1 | tail -5
fi
grep -n "^CXXFLAGS" config.mk | cut -c1-200
make -j8 2>&1 | tail -6
