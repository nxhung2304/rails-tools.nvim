local M = {}

---@param str string
---@return string
function M.camelize(str)
  return (str:gsub("_(%l)", function(c)
    return c:upper()
  end):gsub("^%l", string.upper))
end

---@param word string
---@return string
function M.singularize(word)
  if word:match("ies$") then
    return (word:gsub("ies$", "y"))
  elseif word:match("[sx]es$") or word:match("ches$") or word:match("shes$") then
    return (word:gsub("es$", ""))
  elseif word:match("s$") and not word:match("ss$") then
    return word:sub(1, -2)
  end
  return word
end

---Resolve a receiver expression (`user`, `self`, `current_user`, `orders`, …)
---to one of the project's known model names.
---
---@param receiver string|nil identifier immediately before the dot, or nil for a bare word
---@param known_models table<string, boolean> set of camelized model names present in the project
---@param current_model string|nil model of the buffer being edited, if it's an `app/models/**/*.rb` file
---@return string|nil
function M.infer_model(receiver, known_models, current_model)
  if not receiver then
    return nil
  end
  if receiver == "self" then
    return current_model
  end

  local attempts = { receiver, receiver:match("_([%a][%w]*)$") or receiver }
  for _, word in ipairs(attempts) do
    for _, candidate in ipairs({ M.camelize(word), M.camelize(M.singularize(word)) }) do
      if known_models[candidate] then
        return candidate
      end
    end
  end

  -- Receiver didn't map to any known model (e.g. a generic local var like
  -- `record` or `obj`); inside a model file, assume it refers to the
  -- enclosing model rather than guessing across the whole project.
  return current_model
end

---@param path string absolute or relative file path
---@return string|nil model name (camelized), or nil if the path isn't an app/models file
function M.model_for_path(path)
  local base = path:match("app/models/.-([%w_]+)%.rb$")
  if not base then
    return nil
  end
  return M.camelize(base)
end

return M
