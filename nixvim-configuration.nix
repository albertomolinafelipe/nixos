{ inputs, ... }:

{
  programs.nixvim = {
    enable = true;

    nixpkgs.source = inputs.nixpkgs;

    colorschemes.kanagawa.enable = true;

    globals.mapleader = " ";

    opts = {
      number = true;
      relativenumber = true;

      tabstop = 4;
      softtabstop = 4;
      shiftwidth = 4;
      expandtab = true;

      smartindent = true;
      wrap = true;

      swapfile = false;
      backup = false;
      undodir = "/home/alberto/.vim/undodir";
      undofile = true;

      hlsearch = false;
      incsearch = true;

      termguicolors = true;

      scrolloff = 10;
      signcolumn = "yes";

      updatetime = 50;

      completeopt = "menu,menuone,noselect";
      autoread = true; # needed for opencode auto-reload
    };

    keymaps = [
      # File explorer / terminal
      { mode = "n"; key = "<leader>e"; action = "<cmd>NvimTreeToggle<CR>"; options.desc = "Toggle file tree"; }
      { mode = "n"; key = "<leader>t"; action = "<cmd>ToggleTerm<CR>"; options.desc = "Toggle terminal"; }

      # Harpoon
      { mode = "n"; key = "<leader>a"; action.__raw = ''function() require("harpoon"):list():add() end''; options.desc = "Harpoon add"; }
      { mode = "n"; key = "<leader>h"; action.__raw = ''function() local h = require("harpoon") h.ui:toggle_quick_menu(h:list()) end''; options.desc = "Harpoon menu"; }
      { mode = "n"; key = "<leader>q"; action.__raw = ''function() require("harpoon"):list():clear() end''; options.desc = "Harpoon clear"; }
      { mode = "n"; key = "<C-j>"; action.__raw = ''function() require("harpoon"):list():next() end''; options.desc = "Harpoon next"; }
      { mode = "n"; key = "<C-k>"; action.__raw = ''function() require("harpoon"):list():prev() end''; options.desc = "Harpoon prev"; }

      # OpenCode
      { mode = [ "n" "x" ]; key = "<leader>oa"; action.__raw = ''function() require("opencode").ask("@this: ", { submit = true }) end''; options.desc = "Ask OpenCode about selection/buffer"; }
      { mode = [ "n" "x" ]; key = "<leader>oq"; action.__raw = ''function() require("opencode").ask("", { submit = false }) end''; options.desc = "Quick ask OpenCode"; }
      { mode = "n"; key = "<leader>oe"; action.__raw = ''function() require("opencode").prompt("/editor", { submit = true }) end''; options.desc = "Open OpenCode editor"; }
      { mode = "n"; key = "<leader>ob"; action.__raw = ''function() require("opencode").ask("@this", { submit = true }) end''; options.desc = "Send buffer to OpenCode"; }
      { mode = "x"; key = "<leader>os"; action.__raw = ''function() require("opencode").ask("@this", { submit = true }) end''; options.desc = "Send selection to OpenCode"; }
      { mode = "n"; key = "<leader>oc"; action.__raw = ''function() require("opencode").command("session.new") end''; options.desc = "New OpenCode session"; }
      { mode = "n"; key = "<leader>oh"; action.__raw = ''function() require("opencode").ask("Help me understand what you can do", { submit = true }) end''; options.desc = "OpenCode help"; }
      {
        mode = [ "n" "i" ];
        key = "<C-A-k>";
        options.desc = "Insert file reference for OpenCode";
        action.__raw = ''
          function()
            local file = vim.fn.expand("%:.")
            local line = vim.fn.line(".")
            local reference = "@" .. file .. "#L" .. line
            vim.api.nvim_put({ reference }, "c", true, true)
          end
        '';
      }
      {
        mode = "x";
        key = "<C-A-k>";
        options.desc = "Insert file reference with range for OpenCode";
        action.__raw = ''
          function()
            local file = vim.fn.expand("%:.")
            local start_line = vim.fn.line("'<")
            local end_line = vim.fn.line("'>")
            local reference = "@" .. file .. "#L" .. start_line .. "-" .. end_line
            vim.api.nvim_put({ reference }, "c", true, true)
          end
        '';
      }
    ];

    autoCmd = [
      {
        event = "BufWritePre";
        pattern = "*.go";
        callback.__raw = ''function() vim.lsp.buf.format({ async = false }) end'';
      }
    ];

    extraConfigLua = ''
      -- :G as a Gitsigns wrapper (overrides fugitive's :G)
      vim.api.nvim_create_user_command("G", function(opts)
        local args = vim.trim(opts.args or "")
        if args == "" then
          vim.cmd("Gitsigns")
        else
          vim.cmd("Gitsigns " .. args)
        end
      end, {
        nargs = "*",
        force = true,
        complete = function(arg_lead)
          return vim.fn.getcompletion("Gitsigns " .. arg_lead, "cmdline")
        end,
      })
    '';

    plugins = {
      # Navigation
      telescope = {
        enable = true;
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "grep_string";
        };
      };
      harpoon.enable = true;
      nvim-tree = {
        enable = true;
        settings = {
          sort_by = "extension";
          view.width = 30;
          renderer.group_empty = true;
          filters.dotfiles = false;
          update_focused_file = {
            enable = true;
            update_root = false;
          };
          disable_netrw = true;
          hijack_netrw = true;
        };
      };

      # Cosmetics
      web-devicons.enable = true;
      lualine = {
        enable = true;
        settings.options = {
          component_separators = "";
          section_separators = "";
          theme.__raw = ''
            (function()
              local c = require("kanagawa.colors").setup().theme
              return {
                normal = {
                  a = { bg = c.syn.fun, fg = c.ui.bg_m3 },
                  b = { bg = c.diff.change, fg = c.syn.fun },
                  c = { bg = c.ui.bg_p1, fg = c.ui.fg },
                },
                insert = {
                  a = { bg = c.diag.ok, fg = c.ui.bg },
                  b = { bg = c.ui.bg, fg = c.diag.ok },
                },
                command = {
                  a = { bg = c.syn.operator, fg = c.ui.bg },
                  b = { bg = c.ui.bg, fg = c.syn.operator },
                },
                visual = {
                  a = { bg = c.syn.keyword, fg = c.ui.bg },
                  b = { bg = c.ui.bg, fg = c.syn.keyword },
                },
                replace = {
                  a = { bg = c.syn.constant, fg = c.ui.bg },
                  b = { bg = c.ui.bg, fg = c.syn.constant },
                },
                inactive = {
                  a = { bg = c.ui.bg_m3, fg = c.ui.fg_dim },
                  b = { bg = c.ui.bg_m3, fg = c.ui.fg_dim, gui = "bold" },
                  c = { bg = c.ui.bg_m3, fg = c.ui.fg_dim },
                },
              }
            end)()
          '';
        };
      };
      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };
      };
      treesitter-context = {
        enable = true;
        settings = {
          enable = true;
          max_lines = 3;
          trim_scope = "outer";
          mode = "cursor";
        };
      };
      render-markdown.enable = true;
      undotree.enable = true;

      # Git
      fugitive.enable = true;
      gitsigns.enable = true;
      diffview.enable = true;
      octo.enable = true;

      # LSP
      lsp = {
        enable = true;
        servers = {
          nil_ls.enable = true; # nix
          gopls = {
            enable = true; # go
            settings.gopls.gofumpt = true;
          };
          ts_ls.enable = true; # typescript
          rust_analyzer = {
            enable = true;
            installCargo = true;
            installRustc = true;
          };
          lua_ls = {
            enable = true;
            settings.Lua.diagnostics.globals = [ "vim" ];
          };
          pyright.enable = true; # python
          yamlls.enable = true; # yaml
          jsonls.enable = true; # json
        };
        keymaps = {
          lspBuf = {
            gd = "definition";
            gr = "references";
            gD = "declaration";
            gi = "implementation";
            gt = "type_definition";
            "<leader>rn" = "rename";
            "<C-k>" = "signature_help";
          };
          extra = [
            { key = "K"; mode = "n"; action = "<cmd>Lspsaga hover_doc<CR>"; options.desc = "Hover docs (Lspsaga)"; }
            { key = "<leader>ca"; mode = [ "n" "v" ]; action.__raw = ''function() vim.lsp.buf.code_action() end''; options.desc = "Code action"; }
          ];
        };
      };
      lspsaga = {
        enable = true;
        settings.lightbulb.enable = false;
      };
      trouble.enable = true;

      # Autocompletion
      cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
          snippet.expand = ''function(args) require("luasnip").lsp_expand(args.body) end'';
          mapping = {
            "<C-b>" = "cmp.mapping.scroll_docs(-4)";
            "<C-f>" = "cmp.mapping.scroll_docs(4)";
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-e>" = "cmp.mapping.abort()";
            "<CR>" = "cmp.mapping.confirm({ select = false })";
            "<A-CR>" = "cmp.mapping.confirm({ select = true })";
          };
          sources = [
            { name = "luasnip"; }
            { name = "buffer"; }
            { name = "path"; }
            { name = "nvim_lsp"; }
            { name = "nvim_lua"; }
          ];
        };
      };
      luasnip.enable = true;
      friendly-snippets.enable = true;

      # AI
      opencode.enable = true;

      # QoL
      colorizer.enable = true;
      comment.enable = true;
      nvim-autopairs.enable = true;
      toggleterm.enable = true;
      typst-vim.enable = true;
    };
  };
}
