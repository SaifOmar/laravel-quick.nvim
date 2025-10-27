# `.nvim`

An easy and simple way to run artisan commands in Neovim real "quick".

# Notes

This will be cleaned up later.

# Setup

```lua
require("quick").setup {
}
```

# Features

- Opens a floating window with a list of artisan commands.
- Allows you to search and run artisan commands from the floating window.
- Can refresh the cache of artisan commands if you need to.

# Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'SaiOmar/laravel-quick.nvim',
}
```

# Usage

Use `:Artisan` inside a Laravel project to open a floating window with a list of artisan commands.
Use `:ArtisanRefresh` inside a Laravel project to refresh the cache of artisan commands.


