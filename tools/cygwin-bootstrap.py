#!/usr/bin/env python
# Copyright 2015 The 'mumble-releng' Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that
# can be found in the LICENSE file in the source tree or at
# <http://mumble.info/mumble-releng/LICENSE>.

from __future__ import (unicode_literals, print_function, division)

import os
import sys
import urllib
import collections
import hashlib
import subprocess
import shutil

CYGWIN_MIRRORS = [
	'http://mirrors.dotsrc.org/cygwin',
	'ftp://ftp.cygwin.org/pub/cygwin'
]

CYGWIN_ARCH = 'x86'
PACKAGES = (
	'base-cygwin',
	'cygwin',
	'base-files',
	'bash',
	'patch',
	'tar',
	'xz',
	'gzip',
	'bzip2',
	'hostname',
	'curl',
	'which',
	'unzip',
)

def sevenZipExe():
	return "C:\\Program Files\\7-Zip\\7z.exe"

def gpgExe():
	return "C:\\Program Files (x86)\\GNU\\GnuPG\\pub\\gpg.exe"

def verify(sigFn):
	gpgArgsStr = os.environ['MUMBLE_GPG_CMD']
	gpgArgs = gpgArgsStr.split(' ')
	args = gpgArgs + ['--verify', sigFn]
	cmd(args)

def cmd(args, cwd=None, env=None):
	'''
	cmd executes the requested program and throws an exception
	if if the program returns a non-zero return code.
	'''
	p = subprocess.Popen(args, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
	stdout, stderr = p.communicate()
	ret = p.returncode
	if ret != 0:
		print('## Command "{0}" exited with exit status {1}'.format(args[0], ret))
		print('## Its standard output was:')
		print(stdout)
		print ('## Its standard error output was:')
		print(stderr)
		sys.exit(1)

def tempDir():
	realTempDir = 'c:\\users\\mkrautz\\cygwin-bootstrap'
	if not os.path.exists(realTempDir):
		os.mkdir(realTempDir)
	return realTempDir

def distfilePath(*args):
	return os.path.join(tempDir(), *args)

def checkSHA512(absFn, expectedLength, sha512):
	assert(isinstance(expectedLength, int))
	calcsha512 = hashlib.sha512()
	f = open(absFn, 'rb')
	nread = 0
	while True:
		s = f.read(512)
		if len(s) == 0: # EOF
			break
		nread += len(s)
		calcsha512.update(s)
	if nread != expectedLength:
		raise Exception('Length mismatch for {0}. Has {1}, want {2}.'.format(absFn, nread, expectedLength))
	oursha512 = calcsha512.hexdigest()
	sha512 = sha512.lower()
	if oursha512 != sha512:
		raise Exception('MD5 mismatch for {0}. Has {1}, want {2}.'.format(absFn, calcmd5.hexdigest(), md5))

def ensureDownloaded(mirrorRelativeURL, fileSize=None, sha512sum=None):
	mirrors = []
	mirrors.extend(CYGWIN_MIRRORS)
	mirrors.reverse()

	while True:
		try:
			mirrorBase = mirrors.pop()
		except IndexError:
			raise Exception('Unable to succesfully download {0} from any of the specified mirrors'.format(mirrorRelativeURL))
		url = mirrorBase + "/" + mirrorRelativeURL
		fn = os.path.basename(url)
		def reportFunc(count, blockSize, fullSize):
			percent = int(count*blockSize*100/fullSize)
			if percent > 100:
				percent = 100
			line = '\rDownloading {0}: {1}%'.format(mirrorRelativeURL, percent)
			sys.stdout.write(line)
			sys.stdout.flush()
		outFn = distfilePath(fn)
		urllib.urlretrieve(url, outFn, reportFunc)
		sys.stdout.write('\n')
		sys.stdout.flush()

		if sha512sum is None:
			return
		else:
			if fileSize is None:
				raise Exception('If ensureDownloaded is passed a sha512sum, it must also be passed a fileSize.')
			try:
				checkSHA512(outFn, fileSize, sha512sum)
			except:
				continue
			return

def verifySetupIniSignature():
	setupIniSigPath = distfilePath("setup.ini.sig")
	verify(setupIniSigPath)

def parseSetupIni():
	setupIniPath = distfilePath("setup.ini")
	cygwinDist=collections.OrderedDict()

	f = open(setupIniPath)

	meta = {}
	prefix = ''

	def asciify(line):
		retStr = ''
		for c in line:
			if ord(c) >= 128:
				continue
			retStr += c
		return retStr

	while True:
		line = f.readline()
		line = asciify(line)
		# EOF
		if len(line) == 0:
			break
		# Skip comments
		elif line.startswith('#'):
			continue
		# Context switch
		elif line.startswith('@'):
			pkgName = line[1:].strip()
			meta['name'] = pkgName
		# Sections (we see them as prefixes)
		elif line.startswith('['):
			prefixName = line.strip()[1:-1]
			prefix = prefixName
		# End context
		elif line.strip() == '':
			if meta.get('name', None) == None:
				meta['name'] = '__root__'
			cygwinDist[meta['name']] = meta
			meta = {}
			prefix = ''
		else:
			colon = line.find(':')
			assert(colon >= 0)
			key = line[0:colon]
			global value
			value = line[colon+2:]
			assert(line[colon+1] == ' ')
			if value.find('"') >= 0: # read quoted string
				beforeStrLit = None
				doubleQuoteIdx = value.find('"')
				if doubleQuoteIdx > 1:
					beforeStrLit = value[0:doubleQuoteIdx]
				strLit = ''
				global idx
				idx = doubleQuoteIdx+1
				escapeSequence = False
				def getch():
					global value
					global idx
					retVal = None
					if idx >= len(value):
						nextLine = f.readline()
						nextLine = asciify(nextLine)
						value += nextLine
					retVal = value[idx]
					idx += 1
					return retVal
				while True:
					c = getch()
					if c == '"':
						if escapeSequence:
							strLit += '"'
							escapeSequence = False
							continue
						else:
							break
					elif c == '\\':
						escapeSequence = True
						continue
					else:
						strLit += c
				if beforeStrLit is not None:
					meta[prefix+key] = [beforeStrLit, strLit]
				else:
					meta[prefix+key] = strLit
			elif value.count(' ') > 0: # read list
				meta[prefix+key] = value.strip().split(' ')
			else: # read string
				meta[prefix+key] = value.strip()

	f.close()

	return cygwinDist

def extractTo(absFn, targetDir, extractingCompressedTarball=False):
	absFn = absFn.lower()
	tarFn = absFn
	extensions = ['.tgz', '.tbz', '.tar.xz', '.tar.lzma', '.tar.bz2', '.tar.gz']
	for ext in extensions:
		if absFn.endswith(ext):
			tarFn = absFn.replace(ext, '.tar')

	compressedTarball = absFn != tarFn
	if compressedTarball and not extractingCompressedTarball:
		extractTo(absFn, tempDir(), True)
		extractTo(tarFn, targetDir, True)
	else:
		cmd([sevenZipExe(), 'x', '-y', absFn, '-xr!PaxHeaders.*'], cwd=targetDir)


def installPkg(pkgName, distInfo, targetDir, excludeRequirements=[]):
	'''
		installPkg installs package pkgName.

		The excludeRequirements parameter is provided because
		Cygwin allows circular dependencies.
		In the case of circular dependencies, a base package
		can exclude itself as a requirement when installing
		its own requirements.
	'''

	installedPkgs = distInfo.get('__installed_pkgs__', [])

	if pkgName in installedPkgs:
		print('Skipping {0}. It is already installed'.format(pkgName))
		return

	pkgInfo = distInfo.get(pkgName, None)
	if pkgInfo is None:
		raise Exception('no such package {0}'.format(pkgName))

	requirements = pkgInfo.get('requires', [])
	if not isinstance(requirements, list):
		requirements = [requirements]
	print('requirements for {0}: {1}'.format(pkgName, requirements))
	for req in requirements:
		if req.startswith('_'):
			print('Skipping internal hint: {0}'.format(req))
			continue
		if req in excludeRequirements:
			print('Skipping excluded requirement: {0}'.format(req))
			continue
		if not req in installedPkgs:
			newExcludeRequirements = []
			newExcludeRequirements.extend(excludeRequirements)
			newExcludeRequirements.append(pkgName)
			installPkg(req, distInfo, targetDir, excludeRequirements=newExcludeRequirements)
			installedPkgs = distInfo.get('__installed_pkgs__')

	installInfo = pkgInfo['install']
	relativeUrl = installInfo[0]
	fileSize = installInfo[1]
	sha512sum = installInfo[2]
	ensureDownloaded(relativeUrl, int(fileSize), sha512sum)
	absFn = distfilePath(os.path.basename(relativeUrl))

	if not os.path.exists(targetDir):
		os.mkdir(targetDir)

	extractTo(absFn, targetDir)

	postInstallDir = os.path.join(targetDir, 'etc', 'postinstall')
	for fn in os.listdir(postInstallDir):
		absFn = os.path.join(postInstallDir, fn)
		if absFn.endswith('.done'):
			continue
		bashExe = os.path.join(targetDir, 'bin', 'bash.exe')
		if os.path.exists(bashExe):
			env = os.environ
			# XXX: what about paths with non-ascii in them?
			env['PATH'] = str(os.path.join(targetDir, 'bin') + ';' + env['PATH'])
			cmd([bashExe, '--norc', '--noprofile', absFn], env=env)
			os.rename(absFn, absFn+'.done')

	installedPkgs.append(pkgName)
	distInfo['__installed_pkgs__'] = installedPkgs

def prepareTarget(targetDir):
	dirs = (
		targetDir,
		os.path.join(targetDir, 'usr'),
		os.path.join(targetDir, 'usr', 'bin'),
		os.path.join(targetDir, 'usr', 'lib'),
		os.path.join(targetDir, 'tmp'),
		os.path.join(targetDir, 'dev')
	)

	for absDir in dirs:
		if not os.path.exists(absDir):
			os.mkdir(absDir)

	cmd(["cmd.exe", "/c", "mklink", "/j", "bin", "usr\\bin"], cwd=targetDir)
	cmd(["cmd.exe", "/c", "mklink", "/j", "lib", "usr\\lib"], cwd=targetDir)

def main():
	if len(sys.argv) < 2:
		print('Usage: {0} <target-dir>'.format(os.path.basename(sys.argv[0])))
		sys.exit(1)

	targetDir = sys.argv[1]
	if os.path.exists(targetDir):
		print('Target directory {0} already exists. Aborting.'.format(targetDir))
		sys.exit(1)

	prepareTarget(targetDir)

	ensureDownloaded(CYGWIN_ARCH + "/setup.ini")
	ensureDownloaded(CYGWIN_ARCH + "/setup.ini.sig")

	verifySetupIniSignature()

	distInfo = parseSetupIni()
	for pkg in PACKAGES:
		installPkg(pkg, distInfo, targetDir)

if __name__ == '__main__':
	main()