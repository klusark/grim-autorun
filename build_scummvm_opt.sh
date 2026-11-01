mkdir -p /home/Joel/scummvm/build-opt && cd /home/Joel/scummvm/build-opt
if [ ! -f config.mk ]; then
	# (ccache: CXX and CC go through it; ccache -M 20G, compression and base_dir=/home/Joel/scummvm are set in its own configuration, so that the build directories share hits)
	CXX="ccache g++" CC="ccache gcc" ../configure --disable-all-engines --enable-engines=grim,monkey4 --enable-release 2>&1 | tail -5
fi
grep -n "^CXXFLAGS" config.mk | cut -c1-200
make -j8 2>&1 | tail -6
