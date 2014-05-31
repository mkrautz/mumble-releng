#!/bin/bash -ex
# Copyright 2013-2014 The 'mumble-releng' Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file in the source tree or at
# <http://mumble.info/mumble-releng/LICENSE>.

./install-nasm-binary.bash
./install-cmake-binary.bash

./build-boost.bash
./build-openssl.bash
./build-protobuf.bash

./build-libogg.bash
./build-libvorbis.bash
./build-libflac.bash
./build-libsndfile.bash
./combine-libsndfile-libs.bash

./build-bonjour.bash

./build-zlib.bash

./build-mariadb-client.bash

./build-qt4.bash

./build-libmcpp.bash
./build-bzip2.bash
./build-berkeleydb.bash
./build-expat.bash
./build-zeroc-ice.bash
