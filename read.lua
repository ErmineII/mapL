local reader = {}

function reader.toList(str)
--  str = reader.dequote(str)
  while str:match("^ *\'") do
    str = str:gsub("^ *\' *(.*)$", "(quote . %1)")
  end
  if not reader.parBalanced(str) then error[[
read.lua: lisp reader: parentheses not balanced!
]] end
  str = reader.tokenize(str)
  local collected = {}
  for token in str:gmatch(" *([^ ]+) *") do
    if token == "(" then
      collected = {parent = collected}
    elseif token == ")" then
      if not collected.parent then break end
      local prev = collected
      collected = collected.parent
      collected[#collected+1] = prev
    else collected[#collected + 1] = token:gsub("&sp", " ")
    end
  end
  collected = collected[1]
  return tonumber(collected) or collected
end

function reader.parBalanced(str)
  local count = 0;
  for ch in str:gmatch("[(]") do count = count + 1 end
  for ch in str:gmatch("[)]") do count = count - 1 end
  return count == 0
end

function reader.tokenize(str)
  str = str:gsub("([^\\])\\ ", "%1&sp")
  str = str:gsub("\\&sp", "\\\\ ")
  str = str:gsub("[\n\t]", " ")
  str = str:gsub("([^\\])\'", "%1 ' ")
  str = str:gsub("\\(.)", "%1")
  str = str:gsub("[(]", " ( ")
  str = str:gsub("[)]", " ) ")
  str = str:gsub("  +", " ")
  str = str:gsub("^ +", "")
  str = str:gsub(" +$", "")
  return str
end

--[[
function reader.dequote(str)
  while str:match('"', nil, true) do
    local before = str:match('^(.-)"')
    str = str:match('^.-"(.*)$')
    local collected = '^'
    local before = nil
    local len = 0
    for char in str:gmatch(".") do
      len = len + 1
      if not before then
        before = ""
      end
      if char == " " then
        if before == '"' then
          len = len - 2
          break
        else
          before = char
          collected = collected .. "&sp"
        end
      elseif char == "\'" then
        before = "'"
        collected = collected .. "&sq"
      elseif char == '"' then
        if before == '"' then
          before = ""
          collected = collected .. "&dq"
        else
          before = '"'
        end
      else
        collected = collected .. char
      end
    end -- of for
    print(("\"%s\": %d-len, str: %s, before: %s"):format(collected, len, str, before))
    str = str:sub(len+2)
    str = before .. collected .. str
    print( str )
  end -- of  while
  return str
end
--]]

return reader
