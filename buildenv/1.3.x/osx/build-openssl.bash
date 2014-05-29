#!/bin/bash -ex
# Copyright 2013-2014 The 'mumble-releng' Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file in the source tree or at
# <http://mumble.info/mumble-releng/LICENSE>.

source common.bash
fetch_if_not_exists "http://www.openssl.org/source/openssl-1.0.0l.tar.gz"
expect_sha1 "openssl-1.0.0l.tar.gz" "f7aeaa76a043ab9c1cd5899d09c696d98278e2d7"
expect_sha256 "openssl-1.0.0l.tar.gz" "2a072e67d9e3ae900548c43d7936305ba576025bd083d1e91ff14d68ded1fdec"

tar -zxf openssl-1.0.0l.tar.gz
cd openssl-1.0.0l
./Configure darwin64-x86_64-cc no-shared --prefix=${MUMBLE_PREFIX} --openssldir=${MUMBLE_PREFIX}/openssl
make
make install