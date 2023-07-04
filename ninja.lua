--
-- Name:        premake-ninja/ninja.lua
-- Purpose:     Define the ninja action.
-- Author:      Dmitry Ivanov
-- Created:     2015/07/04
-- Copyright:   (c) 2015 Dmitry Ivanov
--

local p = premake
local tree = p.tree
local project = p.project
local config = p.config
local fileconfig = p.fileconfig

-- Some toolset fixes/helper
p.tools.clang.objectextension = ".o"
p.tools.gcc.objectextension = ".o"
p.tools.msc.objectextension = ".obj"

p.tools.clang.tools.rc = p.tools.clang.tools.rc or "windres"

p.tools.msc.gettoolname = function(cfg, name)
	local map = {cc = "cl", cxx = "cl", ar = "lib", rc = "rc", asm = iif(cfg.platform == "x64", "ml64", "ml")}
	return map[name]
end

-- Ninja module
premake.modules.ninja = {}
local ninja = p.modules.ninja

local function get_key(cfg)
	if cfg.platform then
		return cfg.project.name .. "_" .. cfg.buildcfg .. "_" .. cfg.platform
	else
		return cfg.project.name .. "_" .. cfg.buildcfg
	end
end

local build_cache = {}

local function add_build(cfg, out, implicit_outputs, command, inputs, implicit_inputs, dependencies, vars)
	implicit_outputs = ninja.list(table.translate(implicit_outputs, ninja.esc))
	if #implicit_outputs > 0 then
		implicit_outputs = " |" .. implicit_outputs
	else
		implicit_outputs = ""
	end

	inputs = ninja.list(table.translate(inputs, ninja.esc))

	implicit_inputs = ninja.list(table.translate(implicit_inputs, ninja.esc))
	if #implicit_inputs > 0 then
		implicit_inputs = " |" .. implicit_inputs
	else
		implicit_inputs = ""
	end

	dependencies = ninja.list(table.translate(dependencies, ninja.esc))
	if #dependencies > 0 then
		dependencies = " ||" .. dependencies
	else
		dependencies = ""
	end
	build_line = "build " .. ninja.esc(out) .. implicit_outputs .. ": " .. command .. inputs .. implicit_inputs .. dependencies

	local cached = build_cache[out]
	if cached ~= nil then
		if build_line == cached.build_line
			and table.equals(vars or {}, cached.vars or {})
		then
			-- custom_command rule is identical for each configuration (contrary to other rules)
			-- So we can compare extra parameter
			if string.startswith(cached.command, "custom_command") then
				p.w("# INFO: Rule ignored, same as " .. cached.cfg_key)
			else
				local cfg_key = get_key(cfg)
				p.warn(cached.cfg_key .. " and " .. cfg_key .. " both generate (differently?) " .. out .. ". Ignoring " .. cfg_key)
				p.w("# WARNING: Rule ignored, using the one from " .. cached.cfg_key)
			end
		else
			local cfg_key = get_key(cfg)
			p.warn(cached.cfg_key .. " and " .. cfg_key .. " both generate differently " .. out .. ". Ignoring " .. cfg_key)
			p.w("# ERROR: Rule ignored, using the one from " .. cached.cfg_key)
		end
		p.w("# " .. build_line)
		for i, var in ipairs(vars or {}) do
			p.w("#   " .. var)
		end
		return
	end
	p.w(build_line)
	for i, var in ipairs(vars or {}) do
		p.w("  " .. var)
	end
	build_cache[out] = {
		cfg_key = get_key(cfg),
		build_line = build_line,
		vars = vars
	}
end

function ninja.esc(value)
	value = value:gsub("%$", "$$") -- TODO maybe there is better way
	value = value:gsub(":", "$:")
	value = value:gsub("\n", "$\n")
	value = value:gsub(" ", "$ ")
	return value
end

function ninja.quote(value)
	value = value:gsub("\\", "\\\\")
	value = value:gsub("'", "\\'")
	value = value:gsub("\"", "\\\"")

	return "\"" .. value .. "\""
end

-- in some cases we write file names in rule commands directly
-- so we need to propely escape them
function ninja.shesc(value)
	if type(value) == "table" then
		local result = {}
		local n = #value
		for i = 1, n do
			table.insert(result, ninja.shesc(value[i]))
		end
		return result
	end

	if value:find(" ") then
		return ninja.quote(value)
	end
	return value
end

-- generate solution that will call ninja for projects
function ninja.generateWorkspace(wks)
	local oldGetDefaultSeparator = path.getDefaultSeparator
	path.getDefaultSeparator = function() return "/" end

	p.w("# solution build file")
	p.w("# generated with premake ninja")
	p.w("")

	p.w("# build projects")
	local cfgs = {} -- key is concatenated name or variant name, value is string of outputs names
	local key = ""
	local cfg_first = nil
	local cfg_first_lib = nil

	for prj in p.workspace.eachproject(wks) do
		if p.action.supports(prj.kind) and prj.kind ~= p.NONE then
			for cfg in p.project.eachconfig(prj) do
				key = prj.name .. "_" .. cfg.buildcfg

				if cfg.platform ~= nil then key = key .. "_" .. cfg.platform end
				if not cfgs[cfg.buildcfg] then cfgs[cfg.buildcfg] = {} end
				table.insert(cfgs[cfg.buildcfg], key)

				-- set first configuration name
				if (cfg_first == nil) and (cfg.kind == p.CONSOLEAPP or cfg.kind == p.WINDOWEDAPP) then
					cfg_first = key
				end
				if (cfg_first_lib == nil) and (cfg.kind == p.STATICLIB or cfg.kind == p.SHAREDLIB) then
					cfg_first_lib = key
				end
				if prj.name == wks.startproject then
					cfg_first = key
				end

				-- include other ninja file
				p.w("subninja " .. ninja.esc(ninja.projectCfgFilename(cfg, true)))
			end
		end
	end

	if cfg_first == nil then cfg_first = cfg_first_lib end

	p.w("")

	p.w("# targets")
	for cfg, outputs in pairs(cfgs) do
		p.w("build " .. ninja.esc(cfg) .. ": phony" .. ninja.list(table.translate(outputs, ninja.esc)))
	end
	p.w("")

	p.w("# default target")
	p.w("default " .. ninja.esc(cfg_first))
	p.w("")

	path.getDefaultSeparator = oldGetDefaultSeparator
end

function ninja.list(value)
	if #value > 0 then
		return " " .. table.concat(value, " ")
	else
		return ""
	end
end

local function shouldcompileasc(filecfg)
	if filecfg.compileas and filecfg.compileas ~= "Default" then
		return p.languages.isc(filecfg.compileas)
	end
	return path.iscfile(filecfg.abspath)
end

local function shouldcompileascpp(filecfg)
	if filecfg.compileas and filecfg.compileas ~= "Default" then
		return p.languages.iscpp(filecfg.compileas)
	end
	return path.iscppfile(filecfg.abspath)
end

local function shouldcompileasasm(filecfg)
	return path.isasmfile(filecfg.abspath) or path.hasextension(filecfg.abspath, { ".asm" }) -- `path.isasmfile` actually only checks for `.s`?
end

local function getFileDependencies(cfg)
	local dependencies = {}
	if #cfg.prebuildcommands > 0 or cfg.prebuildmessage then
		dependencies = {"prebuild_" .. get_key(cfg)}
	end
	for i = 1, #cfg.dependson do
		table.insert(dependencies, cfg.dependson[i] .. "_" .. cfg.buildcfg)
	end
	return dependencies
end

local function getcflags(toolset, cfg, filecfg)
	local buildopt = ninja.list(filecfg.buildoptions)
	local cppflags = ninja.list(toolset.getcppflags(filecfg))
	local cflags = ninja.list(toolset.getcflags(filecfg))
	local defines = ninja.list(table.join(toolset.getdefines(filecfg.defines), toolset.getundefines(filecfg.undefines)))
	local includes = ninja.list(toolset.getincludedirs(cfg, filecfg.includedirs, filecfg.externalincludedirs, filecfg.frameworkdirs, filecfg.includedirsafter))
	local forceincludes = ninja.list(toolset.getforceincludes(cfg))

	return buildopt .. cppflags .. cflags .. defines .. includes .. forceincludes
end

local function getcxxflags(toolset, cfg, filecfg)
	local buildopt = ninja.list(filecfg.buildoptions)
	local cppflags = ninja.list(toolset.getcppflags(filecfg))
	local cxxflags = ninja.list(toolset.getcxxflags(filecfg))
	local defines = ninja.list(table.join(toolset.getdefines(filecfg.defines), toolset.getundefines(filecfg.undefines)))
	local includes = ninja.list(toolset.getincludedirs(cfg, filecfg.includedirs, filecfg.externalincludedirs, filecfg.frameworkdirs, filecfg.includedirsafter))
	local forceincludes = ninja.list(toolset.getforceincludes(cfg))
	return buildopt .. cppflags .. cxxflags .. defines .. includes .. forceincludes
end

local function getmasmflags(toolset, cfg, filecfg)
	local defines = ninja.list(table.join(toolset.getdefines(filecfg.defines), toolset.getundefines(filecfg.undefines)))

	local extra = ""
	if filecfg.exceptionhandling == "SEH" then
		extra = extra .. " /safeseh"
	end

	return defines .. extra
end

local function getldflags(toolset, cfg)
	local ldflags = ninja.list(table.join(toolset.getLibraryDirectories(cfg), toolset.getldflags(cfg), cfg.linkoptions))

	-- experimental feature, change install_name of shared libs
	--if (toolset == p.tools.clang) and (cfg.kind == p.SHAREDLIB) and ninja.endsWith(cfg.buildtarget.name, ".dylib") then
	--	ldflags = ldflags .. " -install_name " .. cfg.buildtarget.name
	--end
	return ldflags
end

local function getresflags(toolset, cfg, filecfg)
	local defines = ninja.list(toolset.getdefines(table.join(filecfg.defines, filecfg.resdefines)))
	local includes = ninja.list(toolset.getincludedirs(cfg, table.join(filecfg.externalincludedirs, filecfg.includedirsafter, filecfg.includedirs, filecfg.resincludedirs), {}, {}, {}))
	local options = ninja.list(cfg.resoptions)

	return defines .. includes .. options
end

local function prebuild_rule(cfg)
	if #cfg.prebuildcommands > 0 or cfg.prebuildmessage then
		local commands = {}
		if cfg.prebuildmessage then
			commands = {os.translateCommandsAndPaths("{ECHO} " .. cfg.prebuildmessage, cfg.workspace.basedir, cfg.workspace.location)}
		end
		commands = table.join(commands, os.translateCommandsAndPaths(cfg.prebuildcommands, cfg.workspace.basedir, cfg.workspace.location))
		if (#commands > 1) then
			commands = 'sh -c ' .. ninja.quote(table.implode(commands,"","",";"))
		else
			commands = commands[1]
		end
		p.w("rule run_prebuild")
		p.w("  command = " .. commands)
		p.w("  description = prebuild")
		p.w("")
	end
end

local function prelink_rule(cfg)
	if #cfg.prelinkcommands > 0 or cfg.prelinkmessage then
		local commands = {}
		if cfg.prelinkmessage then
			commands = {os.translateCommandsAndPaths("{ECHO} " .. cfg.prelinkmessage, cfg.workspace.basedir, cfg.workspace.location)}
		end
		commands = table.join(commands, os.translateCommandsAndPaths(cfg.prelinkcommands, cfg.workspace.basedir, cfg.workspace.location))
		if (#commands > 1) then
			commands = 'sh -c ' .. ninja.quote(table.implode(commands,"","",";"))
		else
			commands = commands[1]
		end
		p.w("rule run_prelink")
		p.w("  command = " .. commands)
		p.w("  description = prelink")
		p.w("")
	end
end

local function postbuild_rule(cfg)
	if #cfg.postbuildcommands > 0 or cfg.postbuildmessage then
		local commands = {}
		if cfg.postbuildmessage then
			commands = {os.translateCommandsAndPaths("{ECHO} " .. cfg.postbuildmessage, cfg.workspace.basedir, cfg.workspace.location)}
		end
		commands = table.join(commands, os.translateCommandsAndPaths(cfg.postbuildcommands, cfg.workspace.basedir, cfg.workspace.location))
		if (#commands > 1) then
			commands = 'sh -c ' .. ninja.quote(table.implode(commands,"","",";"))
		else
			commands = commands[1]
		end
		p.w("rule run_postbuild")
		p.w("  command = " .. commands)
		p.w("  description = postbuild")
		p.w("")
	end
end

local function compilation_rules(cfg, toolset, pch)
	---------------------------------------------------- figure out toolset executables
	local cc = toolset.gettoolname(cfg, "cc")
	local cxx = toolset.gettoolname(cfg, "cxx")
	local ar = toolset.gettoolname(cfg, "ar")
	local link = toolset.gettoolname(cfg, iif(cfg.language == "C", "cc", "cxx"))
	local rc = toolset.gettoolname(cfg, "rc")
	local asm = toolset.gettoolname(cfg, "asm")

	local all_cflags = getcflags(toolset, cfg, cfg)
	local all_cxxflags = getcxxflags(toolset, cfg, cfg)
	local all_ldflags = getldflags(toolset, cfg)
	local all_resflags = getresflags(toolset, cfg, cfg)

	if toolset == p.tools.msc then
		-- for some reason Visual Studio add this libraries as "defaults" and premake doesn't tell us this
		local default_msvc_libs = " kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib oleaut32.lib uuid.lib odbc32.lib odbccp32.lib"

		p.w("CFLAGS=" .. all_cflags)
		p.w("rule cc")
		p.w("  command = " .. cc .. " $CFLAGS" .. " /nologo /showIncludes /c /Tc$in /Fo$out")
		p.w("  description = cc $out")
		p.w("  deps = msvc")
		p.w("")
		p.w("CXXFLAGS=" .. all_cxxflags)
		p.w("rule cxx")
		p.w("  command = " .. cxx .. " $CXXFLAGS" .. " /nologo /showIncludes /c /Tp$in /Fo$out")
		p.w("  description = cxx $out")
		p.w("  deps = msvc")
		p.w("")
		p.w("rule asm")
		p.w("  command = " .. asm .. " $ASMFLAGS" .. " /c /nologo /Zi /Fl\"\" /Fo$out /Ta $in")
		p.w("  description = asm $out")
		p.w("  deps = msvc")
		p.w("")
		p.w("RESFLAGS = " .. all_resflags)
		p.w("rule rc")
		p.w("  command = " .. rc .. " /nologo /fo$out $in $RESFLAGS")
		p.w("  description = rc $out")
		p.w("")
		if cfg.kind == p.STATICLIB then
			p.w("rule ar")
			p.w("  command = " .. ar .. " $in /nologo -OUT:$out")
			p.w("  description = ar $out")
			p.w("")
		else
			p.w("rule link")
			p.w("  command = " .. link .. " $in" .. ninja.list(ninja.shesc(toolset.getlinks(cfg, true))) .. default_msvc_libs .. " /link" .. all_ldflags .. " /nologo /out:$out")
			p.w("  description = link $out")
			p.w("")
		end
	elseif toolset == p.tools.clang or toolset == p.tools.gcc then
		local force_include_pch = ""
		if pch then
			force_include_pch = " -include " .. ninja.shesc(pch.placeholder)
			p.w("rule build_pch")
			p.w("  command = " .. iif(cfg.language == "C", cc .. all_cflags .. " -x c-header", cxx .. all_cxxflags .. " -x c++-header")  .. " -H -MMD -MF $out.d -c -o $out $in")
			p.w("  description = build_pch $out")
			p.w("  depfile = $out.d")
			p.w("  deps = gcc")
		end
		p.w("CFLAGS=" .. all_cflags)
		p.w("rule cc")
		p.w("  command = " .. cc .. " $CFLAGS" .. force_include_pch .. " -x c -MMD -MF $out.d -c -o $out $in")
		p.w("  description = cc $out")
		p.w("  depfile = $out.d")
		p.w("  deps = gcc")
		p.w("")
		p.w("CXXFLAGS=" .. all_cxxflags)
		p.w("rule cxx")
		p.w("  command = " .. cxx .. " $CXXFLAGS" .. force_include_pch .. " -x c++ -MMD -MF $out.d -c -o $out $in")
		p.w("  description = cxx $out")
		p.w("  depfile = $out.d")
		p.w("  deps = gcc")
		p.w("")
		p.w("RESFLAGS = " .. all_resflags)
		p.w("rule rc")
		p.w("  command = " .. rc .. " -i $in -o $out $RESFLAGS")
		p.w("  description = rc $out")
		p.w("")
		if cfg.kind == p.STATICLIB then
			p.w("rule ar")
			p.w("  command = " .. ar .. " rcs $out $in")
			p.w("  description = ar $out")
			p.w("")
		else
			local groups = iif(cfg.linkgroups == premake.ON, {"-Wl,--start-group ", " -Wl,--end-group"}, {"", ""})
			p.w("rule link")
			p.w("  command = " .. link .. " -o $out " .. groups[1] .. "$in" .. ninja.list(ninja.shesc(toolset.getlinks(cfg, true, true))) .. all_ldflags .. groups[2])
			p.w("  description = link $out")
			p.w("")
		end
	end
end

local function custom_command_rule()
	p.w("rule custom_command")
	p.w("  command = $CUSTOM_COMMAND")
	p.w("  description = $CUSTOM_DESCRIPTION")
	p.w("")
end

local function collect_generated_files(prj, cfg)
	local generated_files = {}
	tree.traverse(project.getsourcetree(prj), {
	onleaf = function(node, depth)
		function append_to_generated_files(filecfg)
			local outputs = project.getrelative(prj.workspace, filecfg.buildoutputs)
			generated_files = table.join(generated_files, outputs)
		end
		local filecfg = fileconfig.getconfig(node, cfg)
		if not filecfg or filecfg.flags.ExcludeFromBuild then
			return
		end
		local rule = p.global.getRuleForFile(node.name, prj.rules)
		if fileconfig.hasCustomBuildRule(filecfg) then
			append_to_generated_files(filecfg)
		elseif rule then
			local environ = table.shallowcopy(filecfg.environ)

			if rule.propertydefinition then
				p.rule.prepareEnvironment(rule, environ, cfg)
				p.rule.prepareEnvironment(rule, environ, filecfg)
			end
			local rulecfg = p.context.extent(rule, environ)
			append_to_generated_files(rulecfg)
		end
	end,
	}, false, 1)
	return generated_files
end

local function pch_build(cfg, pch)
	local pch_dependency = {}
	if pch then
		pch_dependency = { pch.gch }
		add_build(cfg, pch.gch, {}, "build_pch", {pch.input}, {}, {}, {})
	end
	return pch_dependency
end

local function custom_command_build(prj, cfg, filecfg, filename, file_dependencies)
	local outputs = project.getrelative(prj.workspace, filecfg.buildoutputs)
	local output = outputs[1]
	table.remove(outputs, 1)
	local commands = {}
	if filecfg.buildmessage then
		commands = {os.translateCommandsAndPaths("{ECHO} " .. filecfg.buildmessage, prj.workspace.basedir, prj.workspace.location)}
	end
	commands = table.join(commands, os.translateCommandsAndPaths(filecfg.buildcommands, prj.workspace.basedir, prj.workspace.location))
	if (#commands > 1) then
		commands = 'sh -c ' .. ninja.quote(table.implode(commands,"","",";"))
	else
		commands = commands[1]
	end

	add_build(cfg, output, outputs, "custom_command", {filename}, filecfg.buildinputs, file_dependencies,
		{"CUSTOM_COMMAND = " .. commands, "CUSTOM_DESCRIPTION = custom build " .. ninja.shesc(output)})
end

local function compile_file_build(cfg, filecfg, toolset, pch_dependency, regular_file_dependencies, objfiles)
	local obj_dir = project.getrelative(cfg.workspace, cfg.objdir)
	local filepath = project.getrelative(cfg.workspace, filecfg.abspath)
	local has_custom_settings = fileconfig.hasFileSettings(filecfg)

	if shouldcompileasc(filecfg) or (toolset ~= p.tools.msc and shouldcompileasasm(filecfg)) then
		local objfilename = obj_dir .. "/" .. filecfg.objname .. (toolset.objectextension or ".o")
		objfiles[#objfiles + 1] = objfilename
		local cflags = {}
		if has_custom_settings then
			cflags = {"CFLAGS = $CFLAGS " .. getcflags(toolset, cfg, filecfg)}
		end
		add_build(cfg, objfilename, {}, "cc", {filepath}, pch_dependency, regular_file_dependencies, cflags)
	elseif shouldcompileascpp(filecfg) then
		local objfilename = obj_dir .. "/" .. filecfg.objname .. (toolset.objectextension or ".o")
		objfiles[#objfiles + 1] = objfilename
		local cxxflags = {}
		if has_custom_settings then
			cxxflags = {"CXXFLAGS = $CXXFLAGS " .. getcxxflags(toolset, cfg, filecfg)}
		end
		add_build(cfg, objfilename, {}, "cxx", {filepath}, pch_dependency, regular_file_dependencies, cxxflags)
	elseif shouldcompileasasm(filecfg) and toolset == p.tools.msc then
		local objfilename = obj_dir .. "/" .. filecfg.objname .. (toolset.objectextension or ".o")
		objfiles[#objfiles + 1] = objfilename
		local asmflags = {}
		if has_custom_settings then
			asmflags = {"ASMFLAGS = $ASMFLAGS " .. getmasmflags(toolset, cfg, filecfg)}
		end
		add_build(cfg, objfilename, {}, "asm", {filepath}, {}, {}, asmflags)
	elseif path.isresourcefile(filecfg.abspath) then
		local objfilename = obj_dir .. "/" .. filecfg.name .. ".res"
		objfiles[#objfiles + 1] = objfilename
		local resflags = {}
		if has_custom_settings then
			resflags = {"RESFLAGS = $RESFLAGS " .. getresflags(toolset, cfg, filecfg)}
		end
		add_build(cfg, objfilename, {}, "rc", {filepath}, {}, {}, resflags)
	end
end

local function files_build(prj, cfg, toolset, pch_dependency, regular_file_dependencies, file_dependencies)
	local objfiles = {}
	tree.traverse(project.getsourcetree(prj), {
	onleaf = function(node, depth)
		local filecfg = fileconfig.getconfig(node, cfg)
		if not filecfg or filecfg.flags.ExcludeFromBuild then
			return
		end
		local rule = p.global.getRuleForFile(node.name, prj.rules)
		local filepath = project.getrelative(cfg.workspace, node.abspath)

		if fileconfig.hasCustomBuildRule(filecfg) then
			custom_command_build(prj, cfg, filecfg, filepath, file_dependencies)
		elseif rule then
			local environ = table.shallowcopy(filecfg.environ)

			if rule.propertydefinition then
				p.rule.prepareEnvironment(rule, environ, cfg)
				p.rule.prepareEnvironment(rule, environ, filecfg)
			end
			local rulecfg = p.context.extent(rule, environ)
			custom_command_build(prj, cfg, rulecfg, filepath, file_dependencies)
		else
			compile_file_build(cfg, filecfg, toolset, pch_dependency, regular_file_dependencies, objfiles)
		end
	end,
	}, false, 1)
	p.w("")

	return objfiles
end

local function generated_files_build(cfg, generated_files, key)
	local final_dependency = {}
	if #generated_files > 0 then
		p.w("# generated files")
		add_build(cfg, "generated_files_" .. key, {}, "phony", generated_files, {}, {}, {})
		final_dependency = {"generated_files_" .. key}
	end
	return final_dependency
end

-- generate project + config build file
function ninja.generateProjectCfg(cfg)
	local oldGetDefaultSeparator = path.getDefaultSeparator
	path.getDefaultSeparator = function() return "/" end

	local prj = cfg.project
	local key = prj.name .. "_" .. cfg.buildcfg
	local toolset, toolset_version = p.tools.canonical(cfg.toolset)

	if not toolset then
		p.error("Unknown toolset " .. cfg.toolset)
	end

  -- Some toolset fixes
	cfg.gccprefix = cfg.gccprefix or ""

	p.w("# project build file")
	p.w("# generated with premake ninja")
	p.w("")

	-- premake-ninja relies on scoped rules
	-- and they were added in ninja v1.6
	p.w("ninja_required_version = 1.6")
	p.w("")

	---------------------------------------------------- figure out settings
	local pch = nil
	if toolset ~= p.tools.msc then
		pch = p.tools.gcc.getpch(cfg)
		if pch then
			pch = {
				input = pch,
				placeholder = project.getrelative(cfg.workspace, path.join(cfg.objdir, path.getname(pch))),
				gch = project.getrelative(cfg.workspace, path.join(cfg.objdir, path.getname(pch) .. ".gch"))
			}
		end
	end

	---------------------------------------------------- write rules
	p.w("# core rules for " .. cfg.name)
	prebuild_rule(cfg)
	prelink_rule(cfg)
	postbuild_rule(cfg)
	compilation_rules(cfg, toolset, pch)
	custom_command_rule()

	---------------------------------------------------- build all files
	p.w("# build files")

	local pch_dependency = pch_build(cfg, pch)

	local generated_files = collect_generated_files(prj, cfg)
	local file_dependencies = getFileDependencies(cfg)
	local regular_file_dependencies = table.join(iif(#generated_files > 0, {"generated_files_" .. key}, {}), file_dependencies)

	local obj_dir = project.getrelative(cfg.workspace, cfg.objdir)
	local objfiles = files_build(prj, cfg, toolset, pch_dependency, regular_file_dependencies, file_dependencies)
	local final_dependency = generated_files_build(cfg, generated_files, key)

	---------------------------------------------------- build final target
	if #cfg.prebuildcommands > 0 or cfg.prebuildmessage then
		p.w("# prebuild")
		add_build(cfg, "prebuild_" .. get_key(cfg), {}, "run_prebuild", {}, {}, {}, {})
	end
	local prelink_dependency = {}
	if #cfg.prelinkcommands > 0 or cfg.prelinkmessage then
		p.w("# prelink")
		add_build(cfg, "prelink_" .. get_key(cfg), {}, "run_prelink", {}, objfiles, final_dependency, {})
		prelink_dependency = { "prelink_" .. get_key(cfg) }
	end
	if #cfg.postbuildcommands > 0 or cfg.postbuildmessage then
		p.w("# postbuild")
		add_build(cfg, "postbuild_" .. get_key(cfg), {}, "run_postbuild",  {}, {ninja.outputFilename(cfg)}, {}, {})
	end

	-- we don't pass getlinks(cfg) through dependencies
	-- because system libraries are often not in PATH so ninja can't find them
	local libs = table.translate(config.getlinks(cfg, "siblings", "fullpath"), function (p) return project.getrelative(cfg.workspace, path.join(cfg.project.location, p)) end)
	if cfg.kind == p.STATICLIB then
		p.w("# link static lib")
		add_build(cfg, ninja.outputFilename(cfg), {}, "ar", table.join(objfiles, libs), {}, table.join(final_dependency, prelink_dependency))

	elseif cfg.kind == p.SHAREDLIB then
		local output = ninja.outputFilename(cfg)
		p.w("# link shared lib")

		local extra_outputs = {}
		if ninja.endsWith(output, ".dll") then
			extra_outputs = { ninja.noext(output, ".dll") .. ".lib", ninja.noext(output, ".dll") .. ".exp" }
		elseif ninja.endsWith(output, ".so") then
			-- in case of .so there are no corresponding .a file
		elseif ninja.endsWith(output, ".dylib") then
			-- in case of .dylib there are no corresponding .a file
		else
			p.error("unknown type of shared lib '" .. output .. "', so no idea what to do, sorry")
		end

		add_build(cfg, output, extra_outputs, "link", table.join(objfiles, libs), {}, table.join(final_dependency, prelink_dependency), {})

	elseif (cfg.kind == p.CONSOLEAPP) or (cfg.kind == p.WINDOWEDAPP) then
		p.w("# link executable")
		add_build(cfg, ninja.outputFilename(cfg), {}, "link", table.join(objfiles, libs), {}, table.join(final_dependency, prelink_dependency), {})

	else
		p.error("ninja action doesn't support this kind of target " .. cfg.kind)
	end

	p.w("")
	if #cfg.postbuildcommands > 0 or cfg.postbuildmessage then
		add_build(cfg, key, {}, "phony", {"postbuild_" .. get_key(cfg)}, {}, {}, {})
	else
		add_build(cfg, key, {}, "phony", {ninja.outputFilename(cfg)}, {}, {}, {})
	end
	p.w("")

	path.getDefaultSeparator = oldGetDefaultSeparator
end

-- return name of output binary relative to build folder
function ninja.outputFilename(cfg)
	return project.getrelative(cfg.workspace, cfg.buildtarget.directory) .. "/" .. cfg.buildtarget.name
end

-- return name of build file for configuration
function ninja.projectCfgFilename(cfg, relative)
	if relative ~= nil then
		relative = project.getrelative(cfg.workspace, cfg.location) .. "/"
	else
		relative = ""
	end

	local ninjapath = relative .. "build_" .. cfg.project.name  .. "_" .. cfg.buildcfg

	if cfg.platform ~= nil then ninjapath = ninjapath .. "_" .. cfg.platform end

	return ninjapath .. ".ninja"
end

-- check if string starts with string
function ninja.startsWith(str, starts)
	return str:sub(0, starts:len()) == starts
end

-- check if string ends with string
function ninja.endsWith(str, ends)
	return str:sub(-ends:len()) == ends
end

-- removes extension from string
function ninja.noext(str, ext)
	return str:sub(0, str:len() - ext:len())
end

-- generate all build files for every project configuration
function ninja.generateProject(prj)
	if not p.action.supports(prj.kind) or prj.kind == p.NONE then
		return
	end
	for cfg in project.eachconfig(prj) do
		p.generate(cfg, ninja.projectCfgFilename(cfg), ninja.generateProjectCfg)
	end
end

include("_preload.lua")

return ninja
