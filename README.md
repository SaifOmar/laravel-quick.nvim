# 🌀 Laravel Quick.nvim

> **Run Laravel Artisan commands directly from Neovim — instantly, intuitively, and beautifully.**

`laravel-quick.nvim` gives you a quick floating interface to browse, search, and run Artisan commands inside your Laravel projects — all without leaving Neovim.

---

## ✨ Features

- 🔍 **Floating Command Palette** – Browse and run Artisan commands in a floating window.
- ⚡ **Instant Search** – Uses [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for fuzzy searching through available commands.
- 🔄 **Command Cache Refresh** – Quickly refresh your Artisan command list.
- 🧠 **Smart Detection** – Works only inside Laravel projects (so it stays out of your way elsewhere).

---

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'SaiOmar/laravel-quick.nvim',
    dependencies = {
        'nvim-telescope/telescope.nvim',
    },
    config = function()
        require('quick').setup()
    end,
}


```
## ⚙️ Setup
require("quick").setup({
    -- optional settings can go here
})
## 📝 Commands
  `:Artisan` – Opens the floating command palette.
  `:ArtisanRefresh` – Refreshes the Artisan command list.
