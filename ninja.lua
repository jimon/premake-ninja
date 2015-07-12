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
local solution = p.solution
local config = p.config
local fileconfig = p.fileconfig

premake.modules.ninja = {}
local ninja = p.modules.ninja

function ninja.esc(value)
	return value -- TODO
end

-- generate solution that will call ninja for projects
function ninja.generateSolution(sln)
	p.w("# solution build file")
	p.w("# generated with premake ninja")
	p.w("")

	p.w("# build projects")
	local cfgs = {} -- key is configuration name, value is string of outputs names
	local cfg_first = nil
	for prj in solution.eachproject(sln) do
		for cfg in project.eachconfig(prj) do

			-- fill list of output files
			if not cfgs[cfg.name] then cfgs[cfg.name] = "" end
			cfgs[cfg.name] = cfgs[cfg.name] .. ninja.outputFilename(cfg) .. " "

			-- set first configuration name
			if cfg_first == nil then cfg_first = cfg.name end

			-- include other ninja file
			p.w("subninja " .. ninja.projectCfgFilename(cfg))
		end
	end
	p.w("")

	p.w("# targets")
	for cfg, outputs in pairs(cfgs) do
		p.w("build " .. cfg .. ": phony " .. outputs)
	end
	p.w("")

	p.w("# default target")
	p.w("default " .. cfg_first)
end

function ninja.list(value)
	if #value > 0 then
		return " " .. table.concat(value, " ")
	else
		return ""
	end
end

-- generate project + config build file
function ninja.generateProjectCfg(cfg)
	if cfg.toolset == nil then
		cfg.toolset = "msc" -- TODO why premake doesn't provide default name always ?
	end

	local prj = cfg.project
	local toolset = premake.tools[cfg.toolset]

	p.w("# project build file")
	p.w("# generated with premake ninja")
	p.w("")

	---------------------------------------------------- figure out toolset executables
	local cc = ""
	local cxx = ""
	local ar = ""
	local link = ""
	
	if cfg.toolset == "msc" then
		-- TODO premake doesn't set tools names for msc, do we want to fix it ?
		cc = "cl"
		cxx = "cl"
		ar = "lib"
		link = "cl"
	else
		-- TODO
	end

	---------------------------------------------------- figure out settings
	local buildopt =		ninja.list(cfg.buildoptions)
	local cflags =			ninja.list(toolset.getcflags(cfg))
	local cppflags =		ninja.list(toolset.getcppflags(cfg))
	local cxxflags =		ninja.list(toolset.getcxxflags(cfg))
	local warnings =		ninja.list(toolset.getwarnings(cfg))
	local defines =			ninja.list(table.join(toolset.getdefines(cfg.defines), toolset.getundefines(cfg.undefines)))
	local includes =		ninja.list(premake.esc(toolset.getincludedirs(cfg, cfg.includedirs, cfg.sysincludedirs)))
	local forceincludes =	ninja.list(premake.esc(toolset.getforceincludes(cfg))) -- TODO pch
	local lddeps = 			ninja.list(premake.esc(config.getlinks(cfg, "siblings", "fullpath")))
	local ldflags =			ninja.list(table.join(toolset.getLibraryDirectories(cfg), toolset.getldflags(cfg), cfg.linkoptions))
	local libs =			ninja.list(toolset.getlinks(cfg)) .. lddeps

	local all_cflags = buildopt .. cflags .. warnings .. defines .. includes .. forceincludes
	local all_cxxflags = buildopt .. cflags .. cppflags .. cxxflags .. warnings .. defines .. includes .. forceincludes
	local all_ldflags = buildopt .. ldflags

	local obj_dir = project.getrelative(cfg.project, cfg.objdir)

	---------------------------------------------------- write rules
	p.w("# core rules for " .. cfg.name)
	if cfg.toolset == "msc" then -- TODO /NOLOGO is invalid, we need to use /nologo
		p.w("rule cc")
		p.w("  command = " .. cc .. all_cflags .. " /nologo /showIncludes -c $in /Fo$out")
		p.w("  description = cxx $out")
		p.w("  deps = msvc")
		p.w("rule cxx")
		p.w("  command = " .. cc .. all_cxxflags .. " /nologo /showIncludes -c $in /Fo$out")
		p.w("  description = cxx $out")
		p.w("  deps = msvc")
		p.w("rule ar")
		p.w("  command = " .. ar .. " $in /nologo -OUT:$out")
		p.w("  description = ar $out")
		p.w("rule link")
		p.w("  command = " .. link .. " $in /link " .. all_ldflags .. " /nologo /out:$out")
		p.w("  description = link $out")
		p.w("")
	else
		-- TODO
	end

	---------------------------------------------------- build all files
	p.w("# build files")
	local intermediateExt = function(cfg, var)
		if (var == "c") or (var == "cxx") then
			return iif(cfg.toolset == "msc", ".obj", ".o")
		elseif var == "res" then
			-- TODO
			return ".res"
		elseif var == "link" then
			return cfg.targetextension
		end
	end
	local objfiles = {}
	tree.traverse(project.getsourcetree(prj), {
	onleaf = function(node, depth)
		local filecfg = fileconfig.getconfig(node, cfg)
		if fileconfig.hasCustomBuildRule(filecfg) then
			-- TODO
		elseif path.iscppfile(node.abspath) then
			objfilename = obj_dir .. "/" .. node.objname .. intermediateExt(cfg, "cxx")
			p.w("build " .. objfilename .. ": cxx " .. node.relpath)
			objfiles[#objfiles + 1] = objfilename
		elseif path.isresourcefile(node.abspath) then
			-- TODO
		end
	end,
	}, false, 1)
	p.w("")

	---------------------------------------------------- build final target
	if cfg.kind == premake.STATICLIB then
		p.w("# link static lib")
		p.w("build " .. ninja.outputFilename(cfg) .. ": ar " .. table.concat(objfiles, " ") .. " " .. libs)

	elseif cfg.kind == premake.SHAREDLIB then
		local output = ninja.outputFilename(cfg)
		p.w("# link shared lib")
		p.w("build " .. output .. ": link " .. table.concat(objfiles, " ") .. " " .. libs)

		-- TODO I'm a bit confused here, previous build statement builds .dll/.so file
		-- but there are like no obvious way to tell ninja that .lib/.a is also build there
		-- and we use .lib/.a later on as dependency for linkage
		-- so let's create phony build statements for this, not sure if it's the best solution
		if ninja.endsWith(output, ".dll") then
			p.w("build " .. ninja.noext(output, ".dll") .. ".lib: phony " .. output)
		elseif ninja.endsWith(output, ".so") then
			p.w("build " .. ninja.noext(output, ".so") .. ".a: phony " .. output)
		else
			p.error("unknown type of shared lib '" .. output .. "', so no idea what to do, sorry")
		end

	elseif (cfg.kind == premake.CONSOLEAPP) or (cfg.kind == premake.WINDOWEDAPP) then
		-- TODO windowed app
		p.w("# link executable")
		p.w("build " .. ninja.outputFilename(cfg) .. ": link " .. table.concat(objfiles, " ") .. " " .. libs)

	else
		p.error("ninja action doesn't support this kind of target " .. cfg.kind)
	end
end

-- return name of output binary relative to build folder
function ninja.outputFilename(cfg)
	return project.getrelative(cfg.project, cfg.buildtarget.directory) .. "/" .. cfg.buildtarget.name
end

-- return name of build file for configuration
function ninja.projectCfgFilename(cfg)
	return "build_" .. cfg.project.name  .. "_" .. cfg.name .. ".ninja"
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
	for cfg in project.eachconfig(prj) do
		p.generate(cfg, ninja.projectCfgFilename(cfg), ninja.generateProjectCfg)
	end
end

include("_preload.lua")

return ninja