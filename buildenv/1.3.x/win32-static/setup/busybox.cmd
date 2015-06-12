:: Copyright 2014 The 'mumble-releng' Authors. All rights reserved.
:: Use of this source code is governed by a BSD-style license that
:: can be found in the LICENSE file in the source tree or at
:: <http://mumble.info/mumble-releng/LICENSE>.

:: Transitions the Mumble prep.bat cmd.exe-based
:: build environment to a Cywin environment in 
:: Cygwin's bash shell.

@echo off

%MUMBLE_PREFIX%\mumble-releng\win32\busybox.exe bash -c "source ${MUMBLE_PREFIX}/env && cd ${MUMBLE_PREFIX} && bash"
