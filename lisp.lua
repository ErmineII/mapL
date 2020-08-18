local Notice = [[
    ______
  //  /   \\
 //  |  \/ \\
||    \  \  ||
||  \  \    ||
 \\ /\  |  //
  \\___/__//

  (C) HFH
  probably going to go under the GNU Affero General Public License

]]

local Lisp = {
  fns = {} ,  reader = {} ,  envs = {}
}
Lisp.env = {}
Lisp.Notice = Notice

local helper = {}

-----------------------------------------------------------
--- DATA TYPES
-----------------------------------------------------------

 -----------------------------
 -- Cons
 -----------------------------

local Cons = {class="lispCons"}

function Cons:new(myCar, myCdr)
  local newObj
  if myCdr and myCdr.car == "." then
    myCdr = myCdr.cdr.car
  end
  if myCar and myCar == "\'" then
    myCdr.car = Cons:new('quote', myCdr.car)
    newObj = myCdr
  else
    newObj = {cdr = myCdr, car = myCar}
  end 
  if newObj.car == '' then newObj.car = nil end
  if newObj.cdr == '' then newObj.cdr = nil end
  self.__index = self
  return setmetatable(newObj, self)
end

function Cons:toList()
  local list = {}
  local v = self
  repeat
    list[#list+1] = v.car
    v = v.cdr 
  until not v
  return list
end

function Cons.fromList(list)
  if #list == 0 then
    return nil
  else
    local Car = table.remove(list, 1)
    if type(Car) == 'table' and not Car.class then
      Car = Cons.fromList(Car)
    elseif tonumber(Car) then
      Car = tonumber(Car)
    end
    return Cons:new( Car, Cons.fromList(list) )
  end
end


 -----------------------------
 --- Environments
 -----------------------------

local Env = {class="lispEnv"}

function Env:new(vars, vals)
  newObj = helper.Zip(vars or {}, vals)
  Lisp.envs[1+#Lisp.envs] = newObj
  Lisp.env = newObj
  self.__index = self
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

function Env:del()
  Lisp.env = Lisp.envs[(#Lisp.envs)-1]
  Lisp.envs[#Lisp.envs] = nil
  return self
end

-----------------------------------------------------------
--- BUILTINS
-----------------------------------------------------------

function Lisp.fns.atomp(args)
  local valu = Lisp.eval(args.car)
  if not valu then return "T" end
  if type(valu) == "string" then return valu
  else return nil end
end

Lisp.fns["atom?"] = Lisp.fns.atomp

function Lisp.fns.quote(args)
  return args
end

function Lisp.fns.car(args)
  return (Lisp.eval(args.car)).car
end
function Lisp.fns.cdr(args)
  return (Lisp.eval(args.car)).cdr
end


-----------------------------------------------------------
--- EVAL/ENV
-----------------------------------------------------------

function Lisp.eval(item)
  kind = type(item)
  if kind == "string" then
    local v = tonumber(item) or Lisp.env[item]
    return v and v or nil
  elseif kind == "table" then
    if item.class == "lispCons" then return item:exec() end
  elseif kind == "number" then
    return item
  end
end

function Lisp.begin ()
  Env:new({T='T', _global='T', ['*features*']='practically none'})
end

function Cons:exec()
  if self.car then
    if tonumber(self.car) then
      return self
    elseif Lisp.fns[self.car] then
      return Lisp.fns[self.car](self.cdr)
    else return self:lambdacall() end
  else return nil end
end

function Cons:lambdacall()
  self.car = Lisp.eval(self.car)
  Lisp.env:new(self.car.car:tolist(), self.cdr:tolist())

end

-----------------------------------------------------------
--- READER/PRINTER
-----------------------------------------------------------

Lisp.reader = require("read")

function Lisp.read(str)
  if not str then -- read from stdin
    str = ""
    repeat
      str = str .. io.read()
    until Lisp.reader.parBalanced(str)
  end
  return Cons.fromList(  Lisp.reader.toList( str )  )
end

function Lisp.toString(notp)
  if type(self) == 'table' then
    return (notp and ' ' or '(') ..
      Lisp.toString(self.car) ..
      Lisp.toString(self.cdr or ')', true);
  else
    return tostring(self or '()')
  end
end

-----------------------------

Lisp.Env = Env
Lisp.Cons = Cons

return Lisp
