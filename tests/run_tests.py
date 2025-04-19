# unittests for premake-ninja

import os
import sys
import time
import shutil
import platform
import unittest
import subprocess

# we are changing working directory often in this tests, so let's save current one
current_cwd = os.getcwd()

# if set, will override compiler name when premake is executed
override_compiler = None

# finds the file in path
def which(cmd, mode = os.F_OK | os.X_OK, path = None):
	if sys.version_info[0:2] >= (3, 3):
		return shutil.which(cmd, mode, path)
	else:
		def _access_check(fn, mode):
			return (os.path.exists(fn) and os.access(fn, mode)
					and not os.path.isdir(fn))

		if os.path.dirname(cmd):
			if _access_check(cmd, mode):
				return cmd
			return None

		if path is None:
			path = os.environ.get("PATH", os.defpath)
		if not path:
			return None
		path = path.split(os.pathsep)

		if sys.platform == "win32":
			if not os.curdir in path:
				path.insert(0, os.curdir)
			pathext = os.environ.get("PATHEXT", "").split(os.pathsep)
			if any(cmd.lower().endswith(ext.lower()) for ext in pathext):
				files = [cmd]
			else:
				files = [cmd + ext for ext in pathext]
		else:
			files = [cmd]

		seen = set()
		for dir in path:
			normdir = os.path.normcase(dir)
			if not normdir in seen:
				seen.add(normdir)
				for thefile in files:
					name = os.path.join(dir, thefile)
					if _access_check(name, mode):
						return name
		return None

# ----------------------------------------------------- helper class
class Helper(unittest.TestCase):
	# removes build directory in test folder
	def clear(self, build_dir):
		if os.path.exists(build_dir):
			shutil.rmtree(build_dir)

	# enters test, and clears it
	def enter_test(self, test, build_dir = "build"):
		self.build_dir = build_dir
		os.chdir(current_cwd) # if previous test failed then we need to restore cwd
		os.chdir(test)
		self.clear(build_dir)

	# clears test and exit from it
	def exit_test(self, build_dir = "build"):
		# for some reason call/check_call are not waiting for executable to completely finish
		# so let's wait a bit so we can remove folder safely
		time.sleep(0.3)
		self.clear(build_dir)
		os.chdir(current_cwd)

	# call premake in the test
	def premake(self):
		if override_compiler:
			args = ["premake5", "--scripts=../../..", "--cc=" + override_compiler, "ninja"]
			if override_compiler == "emcc":
				args += ["--os=emscripten"]
			self.assertEqual(subprocess.call(args), 0, "looks like premake failed")
		else:
			self.assertEqual(subprocess.call(["premake5", "--scripts=../../..", "ninja"]), 0, "looks like premake failed")

	# call ninja in the test
	def ninja(self, target = None):
		args = ["ninja", "-C", "build"]
		if target is not None:
			args.append(target)
		self.assertEqual(subprocess.call(args), 0, "looks like ninja failed")

	# get out name with ext and prefix
	def out_name(self, path, ext = None, prefix = None):
		if (ext == None) and (prefix == None):
			return path
		base_path = os.path.dirname(path)
		base_name_and_ext = os.path.splitext(os.path.basename(path))
		if prefix == None:
			prefix = ""
		if ext == None:
			ext = base_name_and_ext[1]
		return base_path + "/" + prefix + base_name_and_ext[0] + ext

	# check if executable exist
	def out_exist(self, path):
		print(f"Looking for {path} in {os.listdir(os.path.dirname(path))}")
		sys.stdout.flush()
		self.assertTrue(
			os.path.exists(path) or
			os.path.exists(self.out_name(path, ".exe")) or
			os.path.exists(self.out_name(path, ".app")) or
			os.path.exists(self.out_name(path, ".lib")) or
			os.path.exists(self.out_name(path, ".a", "lib")) or
			os.path.exists(self.out_name(path, ".dll")) or
			os.path.exists(self.out_name(path, ".so", "lib")) or
			os.path.exists(self.out_name(path, ".dylib", "lib")) or
			os.path.exists(self.out_name(path, ".wasm"))
		)
		print(f"Found {path}")
		sys.stdout.flush()
	# check if executable doesn't exist
	def out_not_exist(self, path):
		self.assertFalse(
			os.path.exists(path) or
			os.path.exists(self.out_name(path, ".exe")) or
			os.path.exists(self.out_name(path, ".app")) or
			os.path.exists(self.out_name(path, ".lib")) or
			os.path.exists(self.out_name(path, ".a", "lib")) or
			os.path.exists(self.out_name(path, ".dll")) or
			os.path.exists(self.out_name(path, ".so", "lib")) or
			os.path.exists(self.out_name(path, ".dylib", "lib")) or
			os.path.exists(self.out_name(path, ".wasm"))
		)

	# check if executable exist
	def exe(self, path):
		if os.path.exists(path):
			current_cwd = os.getcwd()
			os.chdir(self.build_dir)
			executable = os.path.relpath(path, self.build_dir)
			subprocess.check_call([executable], env={'LD_LIBRARY_PATH': os.path.dirname(executable), 'DYLD_LIBRARY_PATH': os.path.dirname(executable)})
			os.chdir(current_cwd)
		elif os.path.exists(path + ".exe"):
			subprocess.check_call([path + ".exe"])
		elif os.path.exists(path + ".app"):
			subprocess.check_call([path + ".app"])
		elif os.path.exists(self.out_name(path, ".lib")) or os.path.exists(self.out_name(path, ".a", "lib")) or os.path.exists(self.out_name(path, ".dll")) or os.path.exists(self.out_name(path, ".so", "lib")) or os.path.exists(self.out_name(path, ".dylib", "lib")):
			pass
		else:
			self.assertTrue(False, "executable '" + path + "' doesn't exist")

	# check basic flow, run debug and release executables
	def check_basics(self, out_debug, out_release, build_dir = "build"):
		# build dir should not exist before premake is called
		self.assertFalse(os.path.exists(build_dir))

		# call premake
		# build dir should exist afterwards, but executables shouldn't
		self.premake()
		self.assertTrue(os.path.exists(build_dir))
		self.out_not_exist(out_debug)
		self.out_not_exist(out_release)

		# call ninja, by default ninja should build debug target
		# so debug executable should exist, and release shouldn't
		self.ninja()
		self.out_exist(out_debug)
		self.out_not_exist(out_release)

		# let's build debug target explicitly, and still release executable shouldn't exist
		self.ninja("debug")
		self.out_exist(out_debug)
		self.out_not_exist(out_release)

		# let's build release target explicitly, all basic executables should exist now
		self.ninja("release")
		self.out_exist(out_debug)
		self.out_exist(out_release)

		# run executables to check if they are valid
		if override_compiler != "emcc":
			self.exe(out_debug)
			self.exe(out_release)

# ----------------------------------------------------- console app tests
class TestConsoleApp(Helper):
	# test simple app
	def test_simple(self):
		self.enter_test("console_app/simple")
		self.check_basics("build/bin_debug/ninjatestprj", "build/bin_release/ninjatestprj")
		self.exit_test()

	# test include path app
	def test_include_path(self):
		self.enter_test("console_app/includepath")
		self.check_basics("build/bin_debug/ninjatestprj", "build/bin_release/ninjatestprj")
		self.exit_test()

# ----------------------------------------------------- static lib tests
class TestStaticLib(Helper):
	# test simple app
	def test_simple(self):
		self.enter_test("static_lib/simple")
		self.check_basics("build/bin_debug/ninjatestprj", "build/bin_release/ninjatestprj")
		self.exit_test()

	# test static lib with app
	def test_withapp(self):
		self.enter_test("static_lib/withapp")
		self.check_basics("build/bin_debug/ninjatestprj_app", "build/bin_release/ninjatestprj_app")
		self.out_exist("build/bin_debug/ninjatestprj_lib test1")
		self.out_exist("build/bin_release/ninjatestprj_lib test1")
		self.out_exist("build/bin_debug/ninjatestprj_lib_test2")
		self.out_exist("build/bin_release/ninjatestprj_lib_test2")
		self.exit_test()

# ----------------------------------------------------- shared lib tests
class TestSharedLib(Helper):
	# test simple app
	def test_simple(self):
		# Skip shared library tests on Emscripten since this is an advanced feature not supported by Premake yet.
		if override_compiler == "emcc":
			return
		self.enter_test("shared_lib/simple")
		self.check_basics("build/bin_debug/ninjatestprj", "build/bin_release/ninjatestprj")
		self.exit_test()

	# test shared lib with app
	def test_withapp(self):
		# Skip shared library tests on Emscripten since this is an advanced feature not supported by Premake yet.
		if override_compiler == "emcc":
			return
		self.enter_test("shared_lib/withapp")
		self.check_basics("build/bin_debug/ninjatestprj_app", "build/bin_release/ninjatestprj_app")
		self.out_exist("build/bin_debug/ninjatestprj_lib_test1")
		self.out_exist("build/bin_release/ninjatestprj_lib_test1")
		self.out_exist("build/bin_debug/ninjatestprj_lib_test2")
		self.out_exist("build/bin_release/ninjatestprj_lib_test2")
		self.exit_test()

# ----------------------------------------------------- windowed app tests
class TestWindowedApp(Helper):
	# test simple app
	def test_simple(self):
		self.enter_test("windowed_app/simple")
		self.check_basics("build/bin_debug/ninjatestprj", "build/bin_release/ninjatestprj")
		self.exit_test()

# ----------------------------------------------------- entry point
if __name__ == "__main__":
	print("-------------------------- test default setup")
	r = unittest.main(exit = False)
	if not r.result.wasSuccessful():
		sys.exit(1)

	if platform.system() == "Windows" and which("gcc"):
		print("-------------------------- found gcc on windows")
		override_compiler = "gcc"
		unittest.main()

	if which("emcc"):
		print("-------------------------- found emcc")
		override_compiler = "emcc"
		unittest.main()
