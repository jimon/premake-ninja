# unittests for premake-ninja

import os
import time
import shutil
import unittest
import subprocess

# we are changing working directory often in this tests, so let's save current one
current_cwd = os.getcwd()

# ----------------------------------------------------- helper class
class Helper(unittest.TestCase):
	# removes build directory in test folder
	def clear(self, build_dir):
		if os.path.exists(build_dir):
			shutil.rmtree(build_dir)

	# enters test, and clears it
	def enter_test(self, test, build_dir = "build"):
		os.chdir(current_cwd) # if previous test failed then we need to restore cwd
		os.chdir(test)
		self.clear(build_dir)

	# clears test and exit from it
	def exit_test(self, build_dir = "build"):
		# for some reason call/check_call are not waiting for executable to completely finish
		# so let's wait a bit so we can remove folder safely
		time.sleep(0.1) 
		self.clear(build_dir)
		os.chdir(current_cwd)

	# call premake in the test
	def premake(self):
		self.assertEqual(
			subprocess.call(["premake5", "--scripts=../../..", "ninja"]), 0,
			"looks like premake failed")

	# call ninja in the test
	def ninja(self, target = None):
		args = ["ninja", "-C", "build"]
		if target is not None:
			args.append(target)
		self.assertEqual(subprocess.call(args), 0,
			"looks like ninja failed")

	# check if executable exist
	def out_exist(self, path):
		self.assertTrue(
			os.path.exists(path) or
			os.path.exists(path + ".exe") or
			os.path.exists(path + ".lib") or
			os.path.exists(path + ".a")
		)

	# check if executable doesn't exist
	def out_not_exist(self, path):
		self.assertFalse(
			os.path.exists(path) or
			os.path.exists(path + ".exe") or
			os.path.exists(path + ".lib") or
			os.path.exists(path + ".a")
		)

	# check if executable exist
	def exe(self, path):
		if os.path.exists(path):
			subprocess.check_call([path])
		elif os.path.exists(path + ".exe"):
			subprocess.check_call([path + ".exe"])
		elif os.path.exists(path + ".lib") or os.path.exists(path + ".a"):
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

	# test staic lib with app
	def test_withapp(self):
		self.enter_test("static_lib/withapp")
		self.check_basics("build/bin_debug/ninjatestprj_app", "build/bin_release/ninjatestprj_app")
		self.out_exist("build/bin_debug/ninjatestprj_lib_test1")
		self.out_exist("build/bin_release/ninjatestprj_lib_test1")
		self.out_exist("build/bin_debug/ninjatestprj_lib_test2")
		self.out_exist("build/bin_release/ninjatestprj_lib_test2")
		self.exit_test()

# ----------------------------------------------------- entry point
if __name__ == "__main__":
	unittest.main()