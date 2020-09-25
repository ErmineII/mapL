local E = {vars = {}, defs = {}}

E.macros = {
  ';\n',--    ')',
  '~',      '=',
  '?',      '|',
  '&',
}

E.operators = {
  '+%-',
  '/*×÷%%',
  '%^',
}

function E.eval(expression)
  if expression == '()' then
    return io.read()
  end

  if expression:find('^ *[0-9,]+%.?[0]* *$') then
    return (expression:gsub('[ ,]', '') :gsub('%.0$',''))
  end -- numbers evaluate to numbers

  if expression:find('^ *[a-z][a-z0-9]* *$') then
    expression = expression:gsub('^ *([a-z][a-z0-9]*) *$', '%1')
    local val = E.vars[expression]
              or E.defs[expression]
              or E.getvariable and E.getvariable(expression)
    if val then return val end
  end

  for _, macro in ipairs(E.macros) do
    if expression:match('['..macro..']') then
      return E.Apply(macro, expression)
    end
  end

  while expression:find('(' ,nil, true) do
    local bef    = expression:match('^(.*)[(][^()]*[)].*$')
    local inside = expression:match('^.*[(]([^()]*)[)].*$')
    local aft    = expression:match('^.*[(][^()]*[)](.*)$')
    expression = bef.. E.eval(inside) ..aft
  end

  for macro, expansion in pairs(E.defs) do
--print( ("%q (%q=>%q)"):format(expression,macro,expansion) )
    return E.eval(expression:gsub(macro, expansion))
  end

  for _,operator in ipairs(E.operators) do
    if expression:match('['..operator..']') then
      return E.Apply(operator, expression)
    end
  end

  return expression
end

function E.Apply(operator, expression)
  local op1 = expression:match('^(.-)['..operator..']')
  local op2 = expression:match('^.-['  ..operator..'](.*)$')
  operator  = expression:match('^.-([' ..operator..'])')
--print( ('%q in %q (%q, %q)'):format(operator, expression, op1,op2) )

  if operator == ')' then
    return E.eval(op1)
  elseif operator == ';' or operator == '\n' then
    E.eval(op1)
    return E.eval(op2)
  elseif operator == '~' then
    E.defs[op1] = op2
    return 0
  elseif operator == '?' then
    op1 = E.eval(op1)
    if tonumber(op1) ~= 0 and op1 ~= '' then
      return E.eval(op2:match('^(.-):'))
    else
      return E.eval(op2:match('^.-:(.*)$'))
    end
  elseif operator == '=' then
    if E.setvariable then
      local val = E.eval(op2)
      E.setvariable(op1, val )
      return val
    else
      E.vars[op1] = E.eval(op2)
      return E.vars[op1]
    end
  end

  op1 = E.eval(op1)
  op2 = E.eval(op2)

  if operator == '/' or operator == '÷' then
    return op1 / op2
  elseif operator == '*' or operator == '×' then
    return op1 * op2
  elseif operator == '+' then
    return op1 + op2
  elseif operator == '-' then
    return op1 - op2
  elseif operator == '%' then
    return op1 % op2
  elseif operator == '^' then
    return op1 ^ op2
  elseif operator == '.' then
    return op1.."."..op2
  else
error(('unknown operator: %q (%q, %q)'):format(operator, op1, op2))
    return '0'
  end
end

--[[ debug
require('doodles_in')
e=E.eval
--]]
return E
