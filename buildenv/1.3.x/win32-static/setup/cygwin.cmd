:: Copyright 2014 The 'mumble-releng' Authors. All rights reserved.
:: Use of this source code is governed by a BSD-style license that
:: can be found in the LICENSE file in the source tree or at
:: <http://mumble.info/mumble-releng/LICENSE>.

:: Transitions the Mumble prep.bat cmd.exe-based
:: build environment to a Cywin environment in 
:: Cygwin's bash shell.

@echo off

:: First, check if we have a locally bootstrapped Cygwin
:: in %MUMBLE_PREFIX%.
set MUMBLE_CYGWIN_ROOT=%MUMBLE_PREFIX%\cygwin
if not exist %MUMBLE_CYGWIN_ROOT% (
	set MUMBLE_CYGWIN_ROOT=
)

:: Try to query the registry for a potential Cygwin
:: installation directory.
if not defined MUMBLE_CYGWIN_ROOT (
	for /f "tokens=2* delims= " %%a in ('reg query "HKCU\Software\Cygwin\Installations"') do set MUMBLE_CYGWIN_ROOT=%%b
	:: Clear the output of reg.exe.
	:: It write an error to stderr if it fails, and we seemingly
	:: cannot redirect it within a "for in" block.
	cls

	:: The registry query worked. Check if the directory actually
	:: exists. If it doesn't, unset MUMBLE_CYGWIN_ROOT such that
	:: the next check (the check below us) will fall back to
	:: using standard Cygwin directories.
	if defined MUMBLE_CYGWIN_ROOT (
		if not exist %MUMBLE_CYGWIN_ROOT% (
			set MUMBLE_CYGWIN_ROOT=
		)
	)
)

:: If the registry query fails, or the directory doesn't exist,
:: try some of the most likely Cygwin directories, and set them
:: as MUMBLE_CYGWIN_ROOT if they exist.
if not defined MUMBLE_CYGWIN_ROOT (
	if exist c:\cygwin (
		set MUMBLE_CYGWIN_ROOT=c:\cygwin
	)
	if exist c:\cygwin64 (
		set MUMBLE_CYGWIN_ROOT=c:\cygwin64
	)
)
:: HKCU\Software\Cygwin\Installations has a weird prefix on the install dir,
:: so strip it if it's there.
if "%MUMBLE_CYGWIN_ROOT:~0,4%" == "\??\" (
	set MUMBLE_CYGWIN_ROOT=%MUMBLE_CYGWIN_ROOT:~4%
)

:: Derefence any symlinks in the Cygwin root.
:: If the c:\MumbleBuild dir is junctioned to somewhere
:: else, Cygwin will complain that there are too many
:: levels of symlinks when %MUMBLE_PREFIX% is accessed
:: through Cygwin. To work around that, we use the 'real'
:: path to Cygwin, so Cygwin doesn't get confused.
for /f %%I in ('%MUMBLE_CYGWIN_ROOT%\bin\realpath %MUMBLE_CYGWIN_ROOT%') do set MUMBLE_CYGWIN_ROOT_POSIXY=%%I
for /f %%I in ('%MUMBLE_CYGWIN_ROOT%\bin\cygpath -w %MUMBLE_CYGWIN_ROOT_POSIXY%') do set MUMBLE_CYGWIN_ROOT=%%I

for /f %%I in ('%MUMBLE_CYGWIN_ROOT%\bin\cygpath %MUMBLE_PREFIX%') do set BOOTSTRAP_CYGWIN_MUMBLE_PREFIX=%%I

%MUMBLE_CYGWIN_ROOT%\bin\bash.exe -c "source /etc/profile && source ${BOOTSTRAP_CYGWIN_MUMBLE_PREFIX}/env && cd ${MUMBLE_PREFIX} && bash"
