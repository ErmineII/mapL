local Banner = [[
    ______
  //  /@@@\\  mapL 
 //  |@@\/@\\  GNU AGPLv3
||    \@@\@@||  (C) HFH 2020
||  \  \@@@@||
 \\ /\  |@@//
  \\___/@@//
]]

local Notice = [[
  MapL, a lisp interpreter
  Copyright (C) 2020  HFH

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU Affero General Public License as published
  by the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Affero General Public License for more details.

  You should have received a copy of the GNU Affero General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]

local Lisp = {
  fns = {} ,  reader = {} ,  envs = {}
}
Lisp.env = {}
Lisp.Notice = Notice; Lisp.Banner = Banner

local helper = {}

-----------------------------------------------------------
--- DATA TYPES
-----------------------------------------------------------

 -----------------------------
 -- Cons
 -----------------------------

local Cons = {class="lispCons"} -- class helps distinguish between tables

function Cons:new(myCar, myCdr) -- used by the reader to make a cons pair
  local newObj
  if myCdr and type(myCdr) ~= 'number'
           and myCdr.car == "." then -- dot-notation makes (a . b)
    if not myCdr.cdr then
      myCdr = newObj
    end
    myCdr = myCdr.cdr.car -- become {car = 'a', cdr = 'b'}
  end -- instead of {  car='a',  cdr={ car='.', cdr={car='b'} }  }
  if myCar and myCar == "\'" then -- (atomp 'a) -> (atomp (quote . a))
    myCdr.car = Cons:new('quote', Cons:new(myCdr.car).car )
    newObj = myCdr
  elseif myCar and myCar == '`' and myCdr then
    myCdr.car = Lisp.eval( myCdr.car )
    newObj = myCdr
  else
    newObj = {cdr = myCdr, car = myCar} -- otherwise a normal cons pair
  end 
  if newObj.car == '' then newObj.car = nil end
  if newObj.cdr == '' then newObj.cdr = nil end
  self.__index = self -- OOP stuff
  return setmetatable(newObj, self)
end

function Cons:toList() -- to a 'List' (a lua table with integer keys)
  local list = {} -- collects values
  local v = self -- current value
  repeat
    table.insert(list , v.car) -- add the value to the list
    v = v.cdr  -- move to the next value
  until not v -- until v == nil (reached the end of the list
  return list
end

function Cons.fromList(list) -- used by the reader
  if type(list) ~= "table" then -- if it is a scalar value, return it
    return list
  end -- otherwise it is a "list"
  if #list == 0 then -- an empty list will return nil ({} => '()')
    return nil
  else
    local Car = table.remove(list, 1) -- separate (a bc) into a + (b c)
    if type(Car) == 'table' and not Car.class then -- where Car = 'a'
      Car = Cons.fromList(Car)
         -- if the Car is a list, recursively process it
    elseif tonumber(Car) then
      Car = tonumber(Car) -- if the Car is a number, store it as one
    end
    return Cons:new( Car, Cons.fromList(list) )
  end -- now process the cdr and finally put it into cons format
end

function Cons:last() -- last element of a cons-list
  local current = self -- current will walk along the cars
  while current.cdr do -- until the cdr is nil
    current = current.cdr
  end
  return current.car -- then return it
end

function Cons:elt(indx) -- indxth element of self (0-based)
  local current = self
  while indx > 0 do -- until we arrive at the correct element
    if not current.cdr then return nil end
    current = current.cdr -- move to the next cell
    indx = indx - 1 -- and decrease the index
  end
  return current.car
end

function Cons:len() -- the length of a cons-list
  local length = 0 -- length
  while self do
    self = self.cdr -- move to the next cdr
    length = length + 1
  end -- until end is reached
  return length
end

 -----------------------------
 --- Environments
 -----------------------------

local Env = {class="lispEnv"} -- variable holder

function Env:new(newObj) -- create a new scope
-- takes a table of vars and vals
  newObj._ns = newObj._ns or false
  table.insert(Lisp.envs, newObj) -- push environment
  Lisp.env = newObj -- Lisp.env points to the current environment
  self.__index = self
   -- when creating a new environment, functions will use Lisp.env:new()
   -- instead of Lisp.Env:new() so that the new environment will inherit
   -- the __index of its parent which is why global variables will still
   -- be accessible from local scopes
  return setmetatable(newObj, self)
end

function helper.Zip(obj1, obj2)
  if not obj2 then return obj1 end
  ret = {}
  for key, val in pairs(obj1) do
    ret[val] = obj2[key]
  end
  return ret
end

function Env:set(name, val) -- set lisp variable name to val
  assert(name ~= "NIL" and name ~= "T", [[
lisp.lua: variable setter: trying to set ]] .. name)
  local indx = #Lisp.envs -- starting at the top of the stack of envs
  while (not Lisp.envs[indx]._ns)
        and indx > 1 do -- until we give up when we've searched everywhere
    local mt = getmetatable(Lisp.envs[indx])
    setmetatable(Lisp.envs[indx], nil)
    if Lisp.envs[indx][name] ~= nil then
      setmetatable(Lisp.envs[indx][name], mt)
      break
    end
    setmetatable(Lisp.envs[indx][name], mt)
    indx = indx - 1 -- check next environment
  end
  Lisp.envs[indx][name] = val
   -- now that we know that name is in L.envs[indx], set it
end

function Env:del() -- deallocate local variables
 -- (letting lua's garbage collector do the low-level stuff)
  Lisp.env = Lisp.envs[(#Lisp.envs) - 1] -- decrement the env pointer
  Lisp.envs[#Lisp.envs] = nil -- remove the last one
  return self
end

-----------------------------------------------------------
--- BUILTINS
-----------------------------------------------------------

function Lisp.fns.let(args)
  if type(args.car) ~= "table" then
    Lisp.env:new{[args.car]=Lisp.eval(args.cdr.car)}
    local rslt = Lisp.fns.progn(args.cdr.cdr)
    Lisp.env:del()
    return rslt
  end
  local vars = {}
  local vals = {}
  local list = args.car
  while list do
    table.insert(vars, list.car)
    list = list.cdr
    table.insert(vals, Lisp.eval(list.car))
    list = list.cdr
  end
  Lisp.env:new(helper.zip(vars, vals))
  local rslt = Lisp.fns.progn(args.cdr.cdr)
  Lisp.env:del()
  return rslt
end

function Lisp.fns.atomp(args) -- is the argument an atom (string)?
  local valu = Lisp.eval(args.car) -- evaluated argument
  if not valu then return "T" end -- nil is an atom, too
  if type(valu) == "string" then return valu
  else return nil end
end

function Lisp.fns.consp(args) -- is the argument a cons pair?
  local valu = Lisp.eval(args.car)
  if not valu then return "T" end -- nil is a cons pair!
  if type(valu) == "table" and valu.class == "lispCons"
    then return valu
  else return nil end
end

-- scheme-style predicates
Lisp.fns["cons?"] = Lisp.fns.consp
Lisp.fns["atom?"] = Lisp.fns.atomp

function Lisp.fns.eq(args) -- two arguments are equal?
  local a = Lisp.eval(args.car)
  return a == Lisp.eval(args.cdr.car) and "T" or nil
end

function Lisp.fns.null(args)
  return not Lisp.eval(args.car)
end

Lisp.fns["nullp"] = Lisp.fns.null
Lisp.fns["null?"] = Lisp.fns.null
Lisp.fns["not"]   = Lisp.fns.null

function Lisp.fns.namespace(args)
  if args.car == "into" then
    Lisp.env:new({ _ns = args.cdr.car })
    Lisp.env[args.cdr.car] = Lisp.env
    local rslt = Lisp.fns.progn(args.cdr.cdr)
    Lisp.env:set(args.cdr.car, Lisp.env:del())
    return rslt
  elseif args.car == "load" then
    Lisp.env:new(Lisp.eval(args.cdr.car))
    local rslt = Lisp.fns.progn(args.cdr.cdr)
    Lisp.env:del()
    return rslt
  else
    error("lisp.lua: unknown namespace manipulation command: "..args.car)
  end
end

 -----------------------------
 --- Control structures
 -----------------------------
 -- all are short-circuiting
 -- and accept variable amounts of arguments
 -----------------------------

Lisp.fns["and"] = function (args)
  local c = nil
  while args do
    c = Lisp.eval(args.car)
    if not c then return nil end
    args = args.cdr
  end
  return c
end

Lisp.fns["or"] = function (args)
  local c = nil
  while args do
    c = Lisp.eval(args.car)
    if c then return c end
    args = args.cdr
  end
  return nil
end

function Lisp.fns.cond (args)
  if args:len() <2 then
    return Lisp.eval(args.car)
  end
  Cond = Lisp.eval(args.car)
  if Cond then
    return Lisp.eval(args.cdr.car)
  else
    return Lisp.fns["if"](args.cdr.cdr)
  end
end

Lisp.fns["if"] = Lisp.fns.cond

Lisp.fns["while"] = function (args)
  local rslt = "T"
  while Lisp.eval(args.car) do
    rslt = Lisp.fns.progn(args.cdr)
  end
  return rslt
end

 -----------------------------
 --- basic list manipulations
 -----------------------------

function Lisp.fns.quote(args)
  return args
end

function Lisp.fns.car(args)
  return (Lisp.eval(args.car)).car
end
function Lisp.fns.cdr(args)
  return (Lisp.eval(args.car)).cdr
end

function Lisp.fns.cons(args)
  return Cons:new(
    Lisp.eval( args.car )  ,
    Lisp.eval( args.cdr.car )  )
end

function Lisp.fns.list(args)
-- TODO: make faster bc it's used by other fns to evaluate arguments
  if not args then return nil end
  return Cons:new( Lisp.eval(args.car) ,  Lisp.fns.list(args.cdr) )
end

function Lisp.fns.qlist(args) -- quasiquoted list
  if type(args.car) == "table" then
    args.car = Lisp.fns.qlist(args)
  elseif args.car == "," and args.cdr.car ~= "," then
    args = args.cdr
    args.car = Lisp.eval(args.car)
  end
  args.cdr = Lisp.fns.qlist(args.cdr)
  return args
end

function Lisp.fns.progn(args) -- like list but only returns last value
  local cons = args
  while cons.cdr do
    Lisp.eval(cons.car)
    cons = cons.cdr
  end
  return Lisp.eval(cons.car)
end

function Lisp.fns.elt(args)
  return Lisp.eval(args.cdr.car):elt(Lisp.eval(args.car))
end

function Lisp.fns.attr(args)
  local val = Lisp.eval(args.cdr.cdr.car)
  Lisp.eval(args,car)[Lisp.eval(args.cdr.car)] = val
  return val
end

 -----------------------------
 -- some wrappers for important fns

function Lisp.fns.eval(args)
  return Lisp.eval(Lisp.eval(args.car))
end

function Lisp.fns.load(args)
  return Lisp.load(Lisp.eval(args.car))
end

function Lisp.fns.read(args)
  if not args then return Lisp.read() end
  return Lisp.read( Lisp.eval(args.car) )
end

function Lisp.fns.print(args)
  args = Lisp.fns.list(args)
  local str = Lisp.toString(args, true)
  str = str:sub(2, str:len() - 1)
  print(str)
  return args
end

 -----------------------------

function Lisp.fns.de(args)
  Lisp.env:set(args.car, args.cdr)
  return args.car
end

Lisp.fns[":="] = function (args)
  local val = Lisp.eval(args.cdr.car)
  Lisp.env:set(args.car, val)
  return val
end

function Lisp.fns.setq(args)
  local ret = nil
  repeat
    ret = Lisp.eval(args.cdr.car)
    Lisp.env:set(args.car, ret)
    args = args.cdr.cdr
  until not args
  return ret
end

Lisp.fns["+"] = function (args)
  local sum = 0
  while args.cdr do
    sum = sum + Lisp.eval(args.car)
    args = args.cdr
  end
  return sum + Lisp.eval(args.car)
end

Lisp.fns["*"] = function (args)
  local product = 1
  while args.cdr do
    product = product * Lisp.eval(args.car)
    args = args.cdr
  end
  return product * Lisp.eval(args.car)
end

Lisp.fns["-"] = function (args)
  local difference = Lisp.eval(args.car)
  repeat
    args = args.cdr
    difference = difference - args.car
  until not args.cdr
  return difference
end

Lisp.fns["/"] = function (args)
  local quotient = Lisp.eval(args.car)
  repeat
    args = args.cdr
    quotient = quotient / args.car
  until not args.cdr
  return quotient
end

 -----------------------------
 -- interface with lua

function Lisp.fns.lua(args)
  local cmd = args.car
  args = Lisp.fns.list(args.cdr)
  if cmd == "funCall" then
    if type(args.car) ~= "function" then
      args.car = _G[args.car]
    end
    return Cons.fromList(
      args.car(  table.unpack( args.cdr:toList() )  )   )
  else
    error("lisp.lua: lua interface: unknown command: " .. cmd)
  end
end

function Lisp.fns.toLisp(args)
  local from = Lisp.eval(args.car)
  if type(from) == "function" then
    return
      (function (Args)
          return Cons.fromList(
            from(  table.unpack( Lisp.fns.list(Args):toList() )  )   );
      end);
  elseif type(from) == "table" and from.class ~="lispCons" then
    return Cons.fromList( from )
  else
    return from
  end
end

Lisp.fns['require'] = function (args)
  args = Lisp.fns.list(args)
  local ret = require("lisp-"..args.car)
  args.car = args.cdr and args.cdr.car or args.car
  lisp.env[args.car] = lisp.env[args.car] or ret
  lisp.env.mod[args.car] = ret
  return ret
end

 -----------------------------
 -- strings

function Lisp.fns.space(args)
  if args then
    return Lisp.fns.join( Cons:new(Cons:new("quote"," "), args) )
  else
    return " "
  end
end  

function Lisp.fns.join(args)
  args = Lisp.fns.list(args)
  local joiner = args.car
  args = args.cdr
  if args:len() == 1 then
    args = args.car
  end
  if not args then return "" end
  local joined = Lisp.toString(args.car)
  args = args.cdr
  while args do
    joined = joined .. joiner ..
               Lisp.toString(args.car)
    args = args.cdr
  end
  return joined
end

function Lisp.fns.split(args)
  local collected = {}
  local str = Lisp.eval(args.car)
  local separator = Lisp.eval(args.cdr.car)
  for fragment in str:gmatch('(.-)'..separator) do
    table.insert(collected, fragment)
  end
  table.insert(collected, str:match('^.*'..separator..'(.-)$'))
  return Cons.fromList(collected)
end

-----------------------------------------------------------
--- EVAL/ENV
-----------------------------------------------------------

function Lisp.eval(item)
  local kind = type(item)
  if kind == "string" then
    local v = tonumber(item) or Lisp.env[item]
    return v and v or nil
  elseif kind == "table" then
    if item.class == "lispCons" then return item:call() end
  else
    return item
  end
end

function Lisp.begin ()
  Env:new({T="T", _ns="T",
    ["*features*"]="practically none", _G=_G, module={}})
  for fn, val in pairs(Lisp.fns) do
    Lisp.env[fn] = val
  end
end

function Cons:call()
  if type(self.car) == "number" then
    return self
  end
  local Car = Lisp.eval(self.car)
  assert(Car, [[
lisp.lua: cons-pair caller: tried to call a nil value: ]]
    .. Lisp.toString(self.car)  )
  if type(Car) == "function" then
    return Car(self.cdr)
  elseif Car.class ~= "lispCons" then
    local key = Lisp.fns.list(self.cdr)
    local val = Car
    while key do
      val = val[key.car]
      key = key.cdr
    end
    return val
  elseif Car.car == "@" then
    Lisp.env:new( {args=Lisp.fns.list(self.cdr)} )
  elseif type(Car.car) == "string" then
    Lisp.env:new( {[Car.car]=self.cdr} )
  else
    Lisp.env:new(helper.zip(Car.car:toList(),
      Lisp.fns.list(self.cdr):toList()))
  end
  local rslt = Lisp.fns.progn(Car.cdr)
  Lisp.env:del()
  return rslt
end

function Lisp.load(file)
  local inp, rslt
  while true do
    inp = Lisp.read(nil, file)
    if not inp then return rslt end
    rslt = Lisp.eval(inp)
  end
end

-----------------------------------------------------------
--- READER/PRINTER
-----------------------------------------------------------

Lisp.reader = require("read")

function Lisp.read(str, file, flag)
-- flag specifies whether this should return what is read in
-- or a table with  the input as the first element, which is
-- important  for distinguishing  between when this  returns
-- nil because it read nil or because it reached the EOF.
  if not str then -- read from file
    str = ""
    file = file or io.stdin
    if type(file) == "string" then file = io.open(file) end
    repeat
      local inp = file:read()
      if not inp then return nil end
      if inp:sub(1,1) == "#" then inp = "" end
      str = str .. inp
    until Lisp.reader.parBalanced(str) and str ~= ""
  end
  return flag and {Cons.fromList(Lisp.reader.toList(str))} or
    Cons.fromList(  Lisp.reader.toList(str)  )
end

function Lisp.toString(from, notp)
  if type(from) == 'table' then
    if type(from.cdr) ~= 'table' and from.cdr then
      from = Cons:new(from.car, Cons:new('.', Cons:new(from.cdr)) )
    end
    return (notp and ' ' or '(') ..
      Lisp.toString(from.car) ..
      Lisp.toString(from.cdr or ')', true);
  else
    return tostring(from or '()')
  end
end

-----------------------------

Lisp.Env = Env
Lisp.Cons = Cons

return Lisp
