### executable must always be installed in /usr/local/bin
yum install -y cmake3
mkdir build
cd build
cmake3 ../helloworld -DCMAKE_INSTALL_PREFIX=/usr/local/bin
make
make install

