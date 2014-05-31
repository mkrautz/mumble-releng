#!/bin/bash -ex
# Copyright 2013-2014 The 'mumble-releng' Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file in the source tree or at
# <http://mumble.info/mumble-releng/LICENSE>.

source common.bash
fetch_if_not_exists "http://ftp.gnu.org/pub/gnu/ncurses/ncurses-5.9.tar.gz"
expect_sha1 "ncurses-5.9.tar.gz" "3e042e5f2c7223bffdaac9646a533b8c758b65b5"
expect_sha256 "ncurses-5.9.tar.gz" "9046298fb440324c9d4135ecea7879ffed8546dd1b58e59430ea07a4633f563b"

tar -zxf ncurses-5.9.tar.gz
cd ncurses-5.9
./configure --prefix=${MUMBLE_PREFIX} --with-shared
make
make install
