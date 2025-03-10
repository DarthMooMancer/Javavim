local M = {}
M.close_key = nil
M.c_build = nil
M.c_run = nil
M.new_c_file = nil
M.new_c_project = nil

-- Default config
M.config = {
  project_root = "~/Projects/C",
  keybinds = {
    ["<Esc>"] = "CloseTerminal",
    ["<leader>cb"] = "CBuild",
    ["<leader>cr"] = "CRun",
    ["<leader>cnf"] = "NewCFile",
    ["<leader>cnp"] = "NewCProject",
  },
  terminal = {
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    top_padding = 0,
    border = true,
    number = true,
    relativenumber = true,
    scroll = true,
  }
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Apply keybindings manually
  for key, command in pairs(M.config.keybinds) do
    if command == "CloseTerminal" then
      M.close_key = key
    end
    if command == "CBuild" then
      M.c_build = key
    end
    if command == "CRun" then
      M.c_run = key
    end
    if command == "NewCFile" then
      M.new_c_file = key
    end
    if command == "NewCProject" then
      M.new_c_project = key
    end
  end

  -- Register Keybinds
  vim.keymap.set("n", M.c_build, ":CBuild<CR>", { silent = true })
  vim.keymap.set("n", M.c_run, ":CRun<CR>", { silent = true })
  vim.keymap.set("n", M.new_c_file, ":NewCFile<CR>", { silent = true })
  vim.keymap.set("n", M.new_c_project, ":NewCProject<CR>", { silent = true })

  -- Register user commands
  vim.api.nvim_create_user_command("NewCProject", M.create_project, {})
  vim.api.nvim_create_user_command("NewCFile", M.create_new_file, {})
  vim.api.nvim_create_user_command("CBuild", M.build, {})
  vim.api.nvim_create_user_command("CRun", M.run, {})
end

-- Open floating terminal
function M.open_float_terminal(cmd)
  local ui = vim.api.nvim_list_uis()[1]
  local term_cfg = M.config.terminal

  -- Default window size (90% of the editor)
  local default_width = math.floor(ui.width * 0.9)
  local default_height = math.floor(ui.height * 0.9)

  -- Default centered position
  local default_row = math.floor((ui.height - default_height) / 2)
  local default_col = math.floor((ui.width - default_width) / 2)

  -- Adjust size based on padding
  local width = default_width - term_cfg.left_padding - term_cfg.right_padding
  local height = default_height - term_cfg.top_padding - (term_cfg.bottom_padding + 1)

  -- Adjust position based on padding
  local row = default_row + term_cfg.top_padding
  local col = default_col + term_cfg.left_padding

  -- Ensure window size doesn't go negative
  width = math.max(1, width)
  height = math.max(1, height)
  -- Ensure position doesn't move off-screen
  row = math.max(0, row)
  col = math.max(0, col)

  -- Create buffer and window
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = term_cfg.border and "rounded" or "none",
  })

  -- Enable scrolling, relative line numbers, and prevent closing on click
  vim.api.nvim_win_set_option(win, "winblend", vim.o.pumblend)
  vim.api.nvim_win_set_option(win, "winhighlight", "Normal:Pmenu,FloatBorder:Pmenu")
  if(M.config.terminal.number == true) then
    vim.api.nvim_win_set_option(win, "number", true)
  end
  if(M.config.terminal.number == true and M.config.terminal.relativenumber == true) then
    vim.api.nvim_win_set_option(win, "relativenumber", true)
  end
  if(M.config.terminal.scroll == true) then
    vim.api.nvim_win_set_option(win, "scrolloff", 5)
  end
  vim.api.nvim_win_set_option(win, "cursorline", true)

  vim.fn.termopen(cmd)

  vim.api.nvim_buf_set_keymap(buf, "n", M.close_key, "i<C-\\><C-n>:q<CR>", { noremap = true, silent = true })
  return buf, win
end

-- Create a new Java project
function M.create_project()
  -- Use vim.ui.input for better handling of input
  vim.ui.input({ prompt = "Enter project name: " }, function(project_name)
    if not project_name or project_name == "" then
      print("Project creation canceled.")
      return
    end

    -- Paths for the project
    local project_root = vim.fn.expand(M.config.project_root) .. "/" .. project_name
    local src_dir = project_root .. "/src"
    local build_dir = project_root .. "/build"
    local include_dir = project_root .. "/include"

    -- Create directories
    vim.fn.mkdir(src_dir, "p")
    vim.fn.mkdir(build_dir, "p")
    vim.fn.mkdir(include_dir, "p")

    -- Write the Main.java file
    local main_c_path = src_dir .. "/main.c"
    local main_c_content = [[
#include <stdio.h>

int main() {
  printf("Hello World\n");
  return 0;
}
]]
    local Cmake_path = project_root .. "/" .. "CMakeLists.txt"
    local Cmake_content = string.format([[
cmake_minimum_required(VERSION 3.10)
project(%s C)
set(CMAKE_C_STANDARD 11)
include_directories(include)

set(SOURCES
    src/main.c
)

add_executable(%s ${SOURCES})
]], project_name, project_name)

    -- Create the file and write content
    local file = io.open(main_c_path, "w")
    if file then
      file:write(main_c_content)
      file:close()
      vim.cmd("edit " .. main_c_path)
      print(" Project '" .. project_name .. "' created at " .. project_root)
    else
      print("Error creating main.c")
    end

    local cmake_file = io.open(Cmake_path, "w")
    if cmake_file then
      cmake_file:write(Cmake_content)
      cmake_file:close()
      vim.cmd("edit " .. project_root)
      print(" Cmake created! '")
    else
      print("Error creating CMakeLists.txt")
    end
  end)
end

-- Create a new Java file
function M.create_new_file()
  vim.ui.input({ prompt = "Enter class name: " }, function(class_name)
    if not class_name or class_name == "" then
      print("Class creation canceled.")
      return
    end

    local current_dir = vim.fn.expand("%:p:h")
    local root_dir = current_dir:match("(.*)/src")
    if not root_dir then
      print("Error: src directory not found.")
      return
    end

    local java_file_path = root_dir .. "/src/" .. class_name .. ".java"
    local java_content = string.format([[
public class %s {
    // New File
}
]], class_name)

    local file = io.open(java_file_path, "w")
    if file then
      file:write(java_content)
      file:close()
      vim.cmd("edit " .. java_file_path)
      print( class_name .. ".java created successfully!")
    else
      print("Error creating " .. class_name .. ".java")
    end
  end)
end

-- Compile Java files
function M.build()
  local current_dir = vim.fn.expand("%:p:h")
  local project_root = current_dir:match("(.*)/src")
  if not project_root then
    print("Error: Must be inside the 'src' directory.")
    return
  end

  local src_dir = project_root .. "/src"
  local out_dir = project_root .. "/build"

  vim.fn.mkdir(out_dir, "p")
  local compile_command = string.format("javac -d %s %s/*.java", out_dir, src_dir)
  local compile_status = vim.fn.system(compile_command)

  if vim.v.shell_error ~= 0 then
    print("Error during compilation:\n" .. compile_status)
  else
    print("Compilation successful!")
  end
end

-- Run Java program in floating terminal
function M.run()
  local current_dir = vim.fn.expand("%:p:h")
  local project_root = current_dir:match("(.*)/src")
  if not project_root then
    print("Error: Must be inside the 'src' directory.")
    return
  end

  local out_dir = project_root .. "/build"
  M.open_float_terminal("java -cp " .. out_dir .. " Main")
end

return M
