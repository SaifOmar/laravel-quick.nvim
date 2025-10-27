local M = require("quick")

vim.api.nvim_create_user_command("Artisan", M.open_artisan_picker, {})
vim.api.nvim_create_user_command("ArtisanRefresh", M.refresh_artisan_cache, {})
vim.api.nvim_create_user_command("GenerateDotEnvFile", M.generate_dot_env_file, {})

-- vim.api.nvim_create_user_command("Laraveldirectory", M.go_to_laravel_directory, {})
-- vim.api.nvim_create_user_command("AddIdeHelperToGitIgnore", M.add_ide_helper_to_gitignore, {})

vim.api.nvim_create_user_command("GetLIH", M.get_laravel_ide_helper, {})
vim.api.nvim_create_user_command("GenearteModelsHelpers", M.generate_models_helpers, {})
vim.api.nvim_create_user_command("GenearteIdeHelper", M.generate_ide_helper_file, {})
-- Keymaps for quick access.
