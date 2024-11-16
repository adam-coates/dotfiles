require("adam.core")
require("adam.lazy")
require("custom_functions")
package.path = package.path .. ";" .. vim.fn.expand("$HOME") .. "/.luarocks/share/lua/5.1/?/init.lua"
package.path = package.path .. ";" .. vim.fn.expand("$HOME") .. "/.luarocks/share/lua/5.1/?.lua"


-- Create a key mapping to call the title function
vim.api.nvim_set_keymap(
	"n",
	"<leader>zt",
	':lua require("custom_functions").title()<CR>',
	{ noremap = true, silent = true }
)
vim.api.nvim_set_keymap(
	"n",
	"<leader>zp",
	':lua require("custom_functions").yaml_ref()<CR>',
	{ noremap = true, silent = true }
)
vim.g.python3_host_prog = "/home/adam/.pyenv/versions/py3/bin/python3"

-- function to renmae buffer to the currently selected highlighted text
function _G.rename_buffer_from_selection()
    -- Get the range of selected text in visual mode
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    local start_line, start_col = start_pos[2], start_pos[3]
    local end_line, end_col = end_pos[2], end_pos[3]

    -- Ensure only one line is selected
    if start_line ~= end_line then
        print("Selection spans multiple lines. Only single-line selection is allowed.")
        return
    end

    -- Get the selected text in the current buffer
    local current_line = vim.fn.getline(start_line)
    local selected_text = string.sub(current_line, start_col, end_col)

    -- Trim whitespace and add ".md" extension for renaming
    selected_text = vim.trim(selected_text) .. ".md"

    -- Rename the buffer (and file) if it's a real file
    local current_path = vim.api.nvim_buf_get_name(0)
    if current_path ~= "" then
        local new_path = vim.fn.fnamemodify(current_path, ":h") .. "/" .. selected_text
        vim.cmd("file " .. new_path)
        print("Renamed buffer to " .. new_path)
    else
        print("Buffer is not associated with a file.")
    end
end
vim.api.nvim_set_keymap(
	"v",
	"<leader>rrr",
	[[:<C-u>lua _G.rename_buffer_from_selection()<CR>]],
	{ noremap = true, silent = true }
)

local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})

local function todoist_integration()
  -- Set your Todoist API token
  local token = os.getenv("TODOIST_API_KEY")   
  local data = nil  -- Will store the latest fetch data

  -- Utility functions
  local function safe_json_decode(str)
    if type(str) ~= "string" then
      return nil
    end
    
    local success, result = pcall(vim.json.decode, str)
    if not success then
      return nil
    end
    return result
  end

  -- Function to get due date input
  local function get_due_date()
    local date_string = vim.fn.input("Enter due date (e.g., 'tomorrow at 10:00', 'monday at 15:00', or press Enter to skip): ")
    if date_string ~= "" then
      return { string = date_string }
    end
    return nil
  end

  -- Function to get reminder settings
  local function get_reminders()
    local reminders = {}
    local add_reminder = vim.fn.input("Add reminder? Enter date/time (e.g., 'monday 10:45am') or press Enter to skip: ")
    
    if add_reminder ~= "" then
      table.insert(reminders, {
        due = { string = add_reminder }
      })
    end
    
    return reminders
  end

  -- Function to get project selection
  local function get_project_selection()
    if not data or not data.projects then return nil end
    
    -- Create project selection menu
    local project_names = {}
    local project_ids = {}
    for _, project in ipairs(data.projects) do
      table.insert(project_names, project.name)
      table.insert(project_ids, project.id)
    end
    
    -- Get the selected project id
    local selected_idx = vim.fn.index(project_names, vim.fn.input("Select project (press Tab to complete): ", "", "customlist," .. table.concat(project_names, "\n"))) + 1
    if selected_idx > 0 then
      return project_ids[selected_idx]
    end
    
    -- Default to Inbox if no selection made
    for i, project in ipairs(data.projects) do
      if project.name == "Inbox" then
        return project.id
      end
    end
    
    return data.projects[1].id
  end

  local function get_due_string(item)
    if not item.due then
      return ""
    end
    
    if type(item.due) == "table" and type(item.due.string) == "string" then
      return " (Due: " .. item.due.string .. ")"
    end
    
    return ""
  end

  local function generate_uuid()
    return vim.fn.system("uuidgen"):gsub("\n", "")
  end

  local function fetch_data()
    local sync_command = string.format(
      'curl -s "https://api.todoist.com/sync/v9/sync" -H "Authorization: Bearer %s" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "sync_token=*" --data-urlencode \'resource_types=["items","projects"]\'',
      token
    )
    
    local sync_result = vim.fn.system(sync_command)
    return safe_json_decode(sync_result)
  end

  local function execute_commands(commands, sync_token)
    if not commands or #commands == 0 then return end

    local commands_json = vim.json.encode(commands)
    local update_command = string.format(
      'curl -s "https://api.todoist.com/sync/v9/sync" -H "Authorization: Bearer %s" -H "Content-Type: application/x-www-form-urlencoded" -d "sync_token=%s" -d "commands=%s"',
      token,
      sync_token,
      commands_json:gsub('"', '\\"')
    )

    local result = vim.fn.system(update_command)
    local decoded_result = safe_json_decode(result)
    return decoded_result
  end

  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_name(buf, 'Todoist Tasks')

  -- Create a new window and set the buffer
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  -- Store task IDs for reference
  local task_ids = {}

  -- Function to get task ID from line number
  local function get_task_id_from_line(line_nr)
    return task_ids[line_nr]
  end

  -- Enhanced function to add task with due date, reminders, and project selection
  local function add_task(content, current_line)
    if not data or not data.projects or #data.projects == 0 then
      print("No projects available")
      return
    end

    -- Determine the project context based on the current line
    local project_id = nil
    local current_project = nil
    
    -- Find the project header above the current line
    for i = current_line, 1, -1 do
      local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1]
      if line and line:match("^### (.+)$") then
        current_project = line:match("^### (.+)$")
        break
      end
    end
    
    -- If we found a project header, find its ID
    if current_project then
      for _, project in ipairs(data.projects) do
        if project.name == current_project then
          project_id = project.id
          break
        end
      end
    end
    
    -- If no project context found, ask for project selection
    if not project_id then
      project_id = get_project_selection()
    end

    -- Get due date and reminders
    local due = get_due_date()
    local reminders = get_reminders()

    -- Create task command
    local task_temp_id = generate_uuid()
    local commands = {}

    local task_args = {
      content = content,
      project_id = project_id
    }

    if due then
      task_args.due = due
    end

    table.insert(commands, {
      type = "item_add",
      temp_id = task_temp_id,
      uuid = generate_uuid(),
      args = task_args
    })

    -- Add reminders if any
    if #reminders > 0 then
      for _, reminder in ipairs(reminders) do
        table.insert(commands, {
          type = "reminder_add",
          temp_id = generate_uuid(),
          uuid = generate_uuid(),
          args = {
            item_id = task_temp_id,
            due = reminder.due
          }
        })
      end
    end

    execute_commands(commands, data.sync_token)
  end

  -- Function to toggle task
  local function toggle_task(task_id)
    local commands = {
      {
        type = "item_close",
        uuid = generate_uuid(),
        args = {
          id = task_id
        }
      }
    }
    execute_commands(commands, data.sync_token)
  end

  -- Function to delete task
  local function delete_task(task_id)
    local commands = {
      {
        type = "item_delete",
        uuid = generate_uuid(),
        args = {
          id = task_id
        }
      }
    }
    execute_commands(commands, data.sync_token)
  end

  -- Function to refresh tasks
  local function refresh_tasks()
    data = fetch_data()
    if not data then return end
    
    -- Clear existing content
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    
    -- Create header
    local lines = {
      "# Todoist Tasks",
      "----------------------",
      "Press <Enter> on empty line to add new task",
      "Press c to toggle task completion",
      "Press dd to delete task",
      "Press r to refresh tasks",
      "",
    }
    
    -- Reset task IDs
    task_ids = {}
    
    -- Group tasks by project
    local projects = {}
    local project_names = {} -- Store project names for sorting
    for _, project in ipairs(data.projects) do
      projects[project.id] = {
        name = project.name,
        tasks = {},
        id = project.id  -- Store the project ID
      }
      table.insert(project_names, {
        name = project.name,
        id = project.id
      })
    end
    
    -- Add tasks to their respective projects
    for _, item in ipairs(data.items) do
      if type(item) == "table" and item.content then
        local project_id = item.project_id
        if projects[project_id] then
          table.insert(projects[project_id].tasks, item)
        end
      end
    end
    
    -- Sort projects (Inbox first, then alphabetically)
    table.sort(project_names, function(a, b)
      if a.name == "Inbox" then
        return true
      elseif b.name == "Inbox" then
        return false
      else
        return a.name:lower() < b.name:lower()
      end
    end)
    
    -- Add tasks grouped by project in the sorted order
    for _, project_info in ipairs(project_names) do
      local project = projects[project_info.id]
      if #project.tasks > 0 then
        table.insert(lines, "### " .. project.name)
        for _, task in ipairs(project.tasks) do
          local checkbox = task.checked and "[x]" or "[ ]"
          local due_str = get_due_string(task)
          local task_line = string.format("- %s %s%s", checkbox, task.content, due_str)
          table.insert(lines, task_line)
          task_ids[#lines - 1] = task.id
        end
        table.insert(lines, "")
      end
    end
    
    -- Update buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  end

  -- Set up keymaps
  local opts = { noremap = true, silent = true, buffer = buf }
  
  -- Add new task with <Enter> on empty lines or lines starting with "- [ ]"
  vim.keymap.set('n', '<CR>', function()
    local line = vim.api.nvim_get_current_line()
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    
    if line:match('^%s*$') or line:match('^-%s*%[%s*%]') then
      local new_task = vim.fn.input('New task: ')
      if new_task ~= '' then
        add_task(new_task, current_line)
        refresh_tasks()
      end
    end
  end, opts)
  
  -- Toggle task completion with c
  vim.keymap.set('n', 'c', function()
    local line_nr = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(buf, line_nr - 1, line_nr, false)[1]
    local task_id = get_task_id_from_line(line_nr - 1)
    if task_id then
      toggle_task(task_id)
      refresh_tasks()
    end
  end, opts)
  
  -- Delete task with dd
  vim.keymap.set('n', 'dd', function()
    local line_nr = vim.api.nvim_win_get_cursor(0)[1]
    local task_id = get_task_id_from_line(line_nr - 1)
    if task_id then
      if vim.fn.confirm('Delete this task?', '&Yes\n&No') == 1 then
        delete_task(task_id)
        refresh_tasks()
      end
    end
  end, opts)

  -- Add refresh mapping
  vim.keymap.set('n', 'r', function()
    refresh_tasks()
    print("Tasks refreshed!")
  end, opts)

  -- Initial refresh
  refresh_tasks()
  
  -- Set up auto-refresh
  local timer = vim.loop.new_timer()
  timer:start(0, 30000, vim.schedule_wrap(function()
    refresh_tasks()
  end))
  
  -- Clean up timer when buffer is closed
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function()
      timer:stop()
      timer:close()
    end
  })
end

-- Create the command
vim.api.nvim_create_user_command('Todoist', todoist_integration, {})

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*.md",
  callback = function()
    vim.cmd("ZenMode")
  end,
})

vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.md",
    callback = function()
        vim.cmd("SoftPencil")
    end,
})


