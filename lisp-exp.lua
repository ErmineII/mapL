exp  =   require('exp')
local
  lisp = require('lisp')

function exp.getvariable(var)
  return lisp.env[var]
end

function exp.setvariable(var, val)
  return lisp.env:set(var, val)
end

local
function ev(args)
  return exp.eval( lisp.fns.space(args) )
end

local
function evq(ar)
  return exp.eval(
    lisp .fns.space(
         lisp.Cons:new(
           lisp.Cons:new('quote', ar) )  )   )
end

local E= {ev=ev, evq=evq}
lisp.env ['#']   = lisp.env['#']   or evq
lisp.env ['exp'] = lisp.env['exp'] or E
return E