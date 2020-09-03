# mapL

> *a lisp implementation, in Lua*

  Inspired by Picolisp (similar lambdas, quoting, etc.)

Tested on lua5.3, PuppyLinux
 and lua5.1, [jslinux](https://bellard.org/jslinux/vm.html?url=alpine-x86.cfg&mem=192)

```lua
lisp=require("lisp")

function lspEvl(str)
  return lisp.eval(lisp.read(str))
end

lspEvl[[
(progn
  (setq x 1 y 2)
  (print (+ x y)) => 3
  (print (space '(this is the closest to strings so far)))
  (de myElt (lst indx)
     (if (eq indx 0)
       (car lst)
       (myElt (cdr lst) (- inx 1)) ) )
  (myElt (3 5 6) 2) => 6  )
]]

```

