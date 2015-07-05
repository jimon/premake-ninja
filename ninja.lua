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

-- generate solution that will call ninja for projects
function ninja.generateSolution(sln)
	p.w("# solution build file")
	p.w("# generated with premake ninja")
	p.w("")
	p.w("rule ninja")
	p.w("  command = ninja -f $in")
	p.w("")

	p.w("# build projects")
	local cfgs = {}
	local cfg_first = nil
	for prj in solution.eachproject(sln) do
		for cfg in project.eachconfig(prj) do
			if not cfgs[cfg] then cfgs[cfg] = "" end
			if cfg_first == nil then cfg_first = cfg.name end
			cfgs[cfg] = cfgs[cfg] .. ninja.outputFilename(cfg) .. " "

			-- well ninja does not have any way to output implicit dependencies, so let's do it by hand
			-- TODO add premake prj dependencies
			local all_files = ""
			tree.traverse(project.getsourcetree(prj), {onleaf = function(node, depth) all_files = all_files .. node.relpath .. " " end,}, false, 1)
			p.w("build " .. ninja.outputFilename(cfg) .. ": ninja " .. ninja.projectCfgFilename(cfg) .. " | " .. all_files)
		end
	end
	p.w("")

	p.w("# targets")
	for cfg, prjs in pairs(cfgs) do
		p.w("build " .. cfg.name .. ": phony " .. prjs)
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

	---------------------------------------------------- figure out settings
	local cc =		"cl" -- TODO, premake doesn't set tools names for msc
	local cxx =		"cl" -- TODO
	local ar =		"link" -- TODO
	local link =	"cl" -- TODO

	local buildopt =		ninja.list(cfg.buildoptions)
	local cflags =			ninja.list(toolset.getcflags(cfg))
	local cppflags =		ninja.list(toolset.getcppflags(cfg))
	local cxxflags =		ninja.list(toolset.getcxxflags(cfg))
	local warnings =		ninja.list(toolset.getwarnings(cfg))
	local defines =			ninja.list(table.join(toolset.getdefines(cfg.defines), toolset.getundefines(cfg.undefines)))
	local includes =		ninja.list(premake.esc(toolset.getincludedirs(cfg, cfg.includedirs, cfg.sysincludedirs)))
	local forceincludes =	ninja.list(premake.esc(toolset.getforceincludes(cfg))) -- TODO pch
	local lddeps =			ninja.list(premake.esc(config.getlinks(cfg, "siblings", "fullpath")))
	local ldflags =			ninja.list(table.join(toolset.getLibraryDirectories(cfg), toolset.getldflags(cfg), cfg.linkoptions))
	local libs =			ninja.list(toolset.getlinks(cfg))

	local all_cflags = buildopt .. cflags .. warnings .. defines .. includes .. forceincludes
	local all_cxxflags = buildopt .. cflags .. cppflags .. cxxflags .. warnings .. defines .. includes .. forceincludes
	local all_ldflags = buildopt .. lddeps .. ldflags .. libs

	local obj_dir = project.getrelative(cfg.project, cfg.objdir)

	---------------------------------------------------- write rules
	p.w("# core rules")
	if cfg.toolset == "msc" then -- TODO /NOLOGO is invalid, we need to use /nologo
		p.w("rule cc_" .. cfg.name)
		p.w("  command = " .. cc .. all_cflags .. " /nologo /showIncludes -c $in /Fo$out")
		p.w("  description = cxx $out")
		p.w("  deps = msvc")
		p.w("rule cxx_" .. cfg.name)
		p.w("  command = " .. cc .. all_cxxflags .. " /nologo /showIncludes -c $in /Fo$out")
		p.w("  description = cxx $out")
		p.w("  deps = msvc")
		--p.w("rule ar")
		--p.w("  command = $ar ") -- TODO
		--p.w("  description = ar $out")
		p.w("rule link_" .. cfg.name)
		p.w("  command = " .. link .. " $in" .. all_ldflags .. " /nologo /link /out:$out")
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
			p.w("build " .. objfilename .. ": cxx_" .. cfg.name .. " " .. node.relpath)
			objfiles[#objfiles + 1] = objfilename
		elseif path.isresourcefile(node.abspath) then
			-- TODO
		end
	end,
	}, false, 1)
	p.w("")

	---------------------------------------------------- build final target
	if cfg.kind == premake.STATICLIB then
		-- TODO
	else
		p.w("# link")
		p.w("build " .. ninja.outputFilename(cfg) .. ": link_" .. cfg.name .. " " .. table.concat(objfiles, " "))
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

-- generate all build files for every project configuration
function ninja.generateProject(prj)
	for cfg in project.eachconfig(prj) do
		p.generate(cfg, ninja.projectCfgFilename(cfg), ninja.generateProjectCfg)
	end
end

include("_preload.lua")

return ninja