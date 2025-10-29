local M = {}
local floating_win = require("window")

M.setup = function(config)
	config = config or {}
end
-- Path for caching the Artisan commands
local cache_path = vim.fn.stdpath("cache") .. "/artisan_commands.json"

-- Attempt to require Telescope modules
local has_telescope, pickers = pcall(require, "telescope.pickers")
local has_telescope_finders, finders = pcall(require, "telescope.finders")
local has_telescope_conf, conf = pcall(require, "telescope.config")
local has_telescope_actions, actions = pcall(require, "telescope.actions")
local actions_state = has_telescope_actions and require("telescope.actions.state") or nil

-- Require my custom floating window module

-- Table to store the commands
M.artisan_commands = {}

--- Returns the path to the artisan file if found.
M.get_artisan_path = function()
	local path = vim.fn.findfile("artisan", vim.fn.getcwd() .. ";")
	return (path ~= "" and path or nil)
end

--- Loads cached commands from disk.
M.load_cached_commands = function()
	local file = io.open(cache_path, "r")
	if file then
		local content = file:read("*a")
		file:close()
		local ok, data = pcall(vim.json.decode, content)
		if ok and data and data.commands then
			M.artisan_commands = data.commands
			return true
		end
	end
	return false
end

--- Saves commands to the cache file.
M.save_cached_commands = function(commands)
	local file = io.open(cache_path, "w")
	if file then
		file:write(vim.json.encode({ commands = commands }))
		file:close()
		vim.notify("Artisan commands have been saved", vim.log.levels.INFO)
	else
		vim.notify("Failed to write Artisan commands cache", vim.log.levels.ERROR)
	end
end

--- Fetches the Artisan commands by calling `php artisan list --format=json`.
M.fetch_artisan_commands = function()
	local artisan = M.get_artisan_path()
	if not artisan then
		vim.notify("No artisan file found in the current directory", vim.log.levels.ERROR)
		return
	end

	local handle = io.popen("php " .. artisan .. " list --format=json 2>/dev/null")
	if handle then
		local result = handle:read("*a")
		handle:close()
		local ok, data = pcall(vim.json.decode, result)
		if ok and data and data.commands then
			M.artisan_commands = data.commands
			M.save_cached_commands(data.commands)
		else
			vim.notify("Failed to fetch Artisan commands", vim.log.levels.ERROR)
		end
	else
		vim.notify("Failed to execute artisan command", vim.log.levels.ERROR)
	end
end

--- Returns the list of Artisan commands, loading from cache if available.
M.get_artisan_commands = function()
	if vim.tbl_isempty(M.artisan_commands) then
		if not M.load_cached_commands() then
			M.fetch_artisan_commands()
		end
	end
	return M.artisan_commands
end

--------------------------------------------------------------------------------
-- Helper: Opens a terminal in a floating window (using your window module)
--------------------------------------------------------------------------------
local function run_in_terminal(cmd)
	local opts = {
		width = math.floor(vim.o.columns * 0.7),
		height = math.floor(vim.o.lines * 0.7),
		border = "rounded",
		title = "Artisan Terminal",
		title_pos = "center",
		winblend = 10, -- slight transparency for aesthetics
	}
	local win_data = floating_win.open_floating_win(opts)
	if not win_data or not win_data.buf or not win_data.win then
		vim.notify("Failed to open Artisan terminal window", vim.log.levels.ERROR)
		return
	end
	local term_bufnr = win_data.buf
	local term_win = win_data.win

	-- (Don't manually set 'buftype' here; termopen will handle that automatically.)

	-- Map keys inside the terminal:
	-- In terminal mode, press <leader>q to close.
	vim.api.nvim_buf_set_keymap(
		term_bufnr,
		"t",
		"<leader>q",
		"<C-\\><C-n>:close<CR>",
		{ noremap = true, silent = true }
	)
	-- In normal mode (after entering terminal normal mode with <C-\\><C-n>), press q to close.
	vim.api.nvim_buf_set_keymap(term_bufnr, "n", "q", ":close<CR>", { noremap = true, silent = true })

	-- Start the terminal job with bash executing the given command.
	local job = vim.fn.termopen({ "bash", "-c", cmd }, {
		on_exit = function(_, exit_code, _)
			if exit_code ~= 0 then
				vim.schedule(function()
					vim.notify("Artisan command exited with error code: " .. exit_code, vim.log.levels.ERROR)
				end)
			end
		end,
	})
	if job == 0 then
		vim.notify("Failed to start terminal job", vim.log.levels.ERROR)
	end
end

--------------------------------------------------------------------------------
-- Runs the selected Artisan command.
--------------------------------------------------------------------------------
M.run_artisan_command = function(command)
	local artisan = M.get_artisan_path()
	if not artisan then
		vim.print("No artisan file found in the current directory")
		return
	end

	local cmd_details = nil
	for _, cmd in ipairs(M.artisan_commands) do
		if cmd.name == command then
			cmd_details = cmd
			break
		end
	end

	if not cmd_details then
		vim.notify("Command not found", vim.log.levels.ERROR)
		return
	end

	local command_string = "php " .. artisan .. " " .. command
	-- If the command appears to need parameters, prompt the user.
	if type(cmd_details.definition) == "string" and cmd_details.definition:match("%{%w+%}") then
		vim.ui.input({ prompt = "Enter parameters: " }, function(input)
			if input and input ~= "" then
				command_string = command_string .. " " .. input
			end
			run_in_terminal(command_string)
		end)
	else
		run_in_terminal(command_string)
	end
end

M.make_action = function()
	vim.ui.input({ prompt = "Enter the name of the action: " }, function(input)
		if input and input ~= "" then
			M.make_action_file(input)
		end
	end)
end

M._action_template = [[<?php

namespace App\Actions{{extra}};


class {{action_name}}
{
}]]

M.get_laravel_root = function()
	local artisan = M.get_artisan_path()
	if not artisan then
		return nil
	end

	return vim.fn.fnamemodify(artisan, ":h")
end

-- TODO: optimize
M.make_action_file = function(path)
	local root = M.get_laravel_root()
	if not root then
		vim.notify("Please make sure you are in a Laravel project", vim.log.levels.ERROR, { title = "Laravel Quick" })
		return
	end
	path = path:gsub("%.php$", "")
	path = path:gsub("\\", "/")
	local parts = vim.split(path, "/")
	-- this is the lua way of getting the last element of a table
	local action_name = parts[#parts]
	local extra = table.concat(parts, "/", 1, #parts - 1)
	local action_directory = root .. "/app/Actions/" .. extra
	if vim.fn.isdirectory(action_directory) == 0 then
		vim.fn.mkdir(action_directory, "p")
	end
	local file_path = action_directory .. "/" .. action_name .. ".php"
	local file = io.open(file_path, "w")
	if file then
		local string = M._action_template:gsub("{{action_name}}", action_name)
		extra = extra:gsub("/", "\\")
		string = string:gsub("{{extra}}", "\\" .. extra)
		file:write(string)
		vim.notify("Action file created successfully", vim.log.levels.INFO, { title = "Laravel Quick" })
	else
		vim.notify("Action file creation failed ", vim.log.levels.ERROR, { title = "Laravel Quick" })
		return false
	end
end

--------------------------------------------------------------------------------
-- Opens a searchable picker for Artisan commands using Telescope (or a fallback).
--------------------------------------------------------------------------------
M.open_artisan_picker = function()
	local commands = M.get_artisan_commands()
	if vim.tbl_isempty(commands) then
		return
	end

	local command_list = {}
	for _, cmd in ipairs(commands) do
		table.insert(command_list, { cmd.name, cmd.description or "" })
	end

	if has_telescope and has_telescope_finders and has_telescope_conf and has_telescope_actions then
		pickers
			.new({}, {
				prompt_title = "Laravel Artisan Commands",
				finder = finders.new_table({
					results = command_list,
					entry_maker = function(entry)
						return {
							value = entry[1],
							display = entry[1] .. " - " .. entry[2],
							ordinal = entry[1],
						}
					end,
				}),
				sorter = conf.values.generic_sorter({}),
				attach_mappings = function(prompt_bufnr, _)
					actions.select_default:replace(function()
						local selection = actions_state.get_selected_entry(prompt_bufnr)
						actions.close(prompt_bufnr)
						if selection then
							M.run_artisan_command(selection.value)
						end
					end)
					return true
				end,
			})
			:find()
	else
		-- Fallback: display the list in your custom floating window.
		local win_data = floating_win.open_floating_win({
			width = math.floor(vim.o.columns * 0.7),
			height = math.floor(vim.o.lines * 0.7),
			border = "rounded",
			title = "Laravel Artisan Commands",
			title_pos = "center",
		})
		local buf = win_data.buf
		local lines = {}
		for _, entry in ipairs(command_list) do
			table.insert(lines, entry[1] .. " - " .. entry[2])
		end
		vim.api.nvim_buf_set_option(buf, "modifiable", true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
		vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
			noremap = true,
			silent = true,
			callback = function()
				local line = vim.api.nvim_get_current_line()
				local cmd = line:match("^(%S+)")
				if cmd then
					M.run_artisan_command(cmd)
				end
			end,
		})
	end
end

--------------------------------------------------------------------------------
-- Refreshes the Artisan commands cache.
--------------------------------------------------------------------------------
M.refresh_artisan_cache = function()
	M.fetch_artisan_commands()
end

-- M.go_to_laravel_directory = function()
-- 	-- we need to check if I am on wsl or on windows then use the correct path
-- 	--  windows_path = "E:\\dev\\laravel"
-- 	-- wsl_path = "~/dev/laravel"
-- 	local is_wsl = vim.fn.has("wsl") == 1
--
-- 	local laravel_path = ""
-- 	if is_wsl then
-- 		-- WSL path
-- 		laravel_path = "~/dev/laravel"
-- 	else
-- 		-- Windows path
-- 		laravel_path = "E:\\dev\\laravel"
-- 	end
-- 	-- now change directory the larvel path
-- 	vim.cmd("cd " .. laravel_path)
--
-- 	if not has_telescope then
-- 		vim.notify("Telescope is not installed", vim.log.levels.ERROR)
-- 		return
-- 	end
--
-- 	local projects = vim.fn.split(vim.fn.glob(laravel_path .. "/*"), "\n")
--
-- 	-- Filter to only include directories
-- 	local project_dirs = {}
-- 	for _, project in ipairs(projects) do
-- 		if vim.fn.isdirectory(project) == 1 then
-- 			table.insert(project_dirs, project)
-- 		end
-- 	end
--
-- 	-- Create a table to store the project names for display
-- 	local project_names = {}
-- 	for _, project in ipairs(project_dirs) do
-- 		-- Get the name of the project
-- 		local name = vim.fn.fnamemodify(project, ":t")
-- 		table.insert(project_names, name)
-- 	end
--
-- 	-- Exit if no projects found
-- 	if #project_names == 0 then
-- 		vim.notify("No Laravel projects found in " .. laravel_path, vim.log.levels.WARN)
-- 		return
-- 	end
-- 	pickers
-- 		.new({}, {
-- 			prompt_title = "Laravel Projects",
-- 			finder = finders.new_table({
-- 				results = project_names,
-- 				entry_maker = function(entry)
-- 					return {
-- 						value = entry,
-- 						display = entry,
-- 						ordinal = entry,
-- 					}
-- 				end,
-- 			}),
-- 			sorter = conf.values.generic_sorter({}),
-- 			attach_mappings = function(prompt_bufnr, map)
-- 				actions.select_default:replace(function()
-- 					local selection = actions_state.get_selected_entry(prompt_bufnr)
-- 					actions.close(prompt_bufnr)
-- 					if selection then
-- 						-- Find the full path for the selected project
-- 						local selected_project = nil
-- 						for _, project in ipairs(project_dirs) do
-- 							if vim.fn.fnamemodify(project, ":t") == selection.value then
-- 								selected_project = project
-- 								break
-- 							end
-- 						end
--
-- 						if selected_project then
-- 							-- Change directory to the selected project
-- 							vim.cmd("cd " .. selected_project)
-- 							vim.notify("Changed to project: " .. selection.value, vim.log.levels.INFO)
-- 							vim.cmd("Telescope find_files")
-- 							-- vim.cmd("Ex" .. selected_project)
-- 						end
-- 					end
-- 				end)
-- 				return true
-- 			end,
-- 		})
-- 		:find()
-- end

-- installs laravel ide helper
M.get_laravel_ide_helper = function()
	local artisan = M.get_artisan_path()
	if not artisan then
		return
	end
	local cmd = "composer require --dev barryvdh/laravel-ide-helper"
	vim.cmd("terminal " .. cmd)
end

-- we are going to run the commands for laravel ide helper
M.generate_ide_helper_file = function()
	if not M.get_artisan_path() then
		return
	end
	local cmd = "php artisan ide-helper:generate"
	vim.cmd("terminal " .. cmd)
end

M.generate_models_helpers = function()
	if not M.get_artisan_path() then
		return
	end
	local cmd = "php artisan ide-helper:models -RW"
	vim.cmd("terminal " .. cmd)
end

-- M.add_ide_helper_to_gitignore = function()
-- 	if not M.get_artisan_path() then
-- 		return
-- 	end
-- 	local cmd = 'echo "_ide_helper.php" >> .gitignore  echo "_ide_helper_models.php" >> .gitignore'
-- 	vim.cmd("terminal " .. cmd)
-- end

M.generate_dot_env_file = function()
	if not M.get_artisan_path() then
		return
	end
	local cmd = "cp .env.example .env"
	vim.cmd("terminal " .. cmd)
end
return M
-- User commands.
