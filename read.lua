local reader = {}

function reader.toList(str)
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
    else collected[#collected + 1] = token
    end
  end
  collected = collected[1]
  return collected
end

function reader.parBalanced(str)
  local count = 0;
  for ch in str:gmatch("[(]") do count = count + 1 end
  for ch in str:gmatch("[)]") do count = count - 1 end
  return count == 0
end

function reader.tokenize(str)
  str = str:gsub("[\n\t]", " ")
  str = str:gsub( "\'", " ' ")
  str = str:gsub("[(]", " ( ")
  str = str:gsub("[)]", " ) ")
  str = str:gsub("  +", " ")
  str = str:gsub("^ +", "")
  str = str:gsub(" +$", "")
  return str
end

return reader
