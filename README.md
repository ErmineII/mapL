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

lisp.begin()

lspEvl[[
```
```lisp
(progn
   (setq x 1 y 2)
   (print (+ x y)) => 3
   (print (space '(this is the closest to strings so far)))
   (de myElt (lst indx)
      (if (eq indx 0)
         (car lst)
         (myElt (cdr lst) (- indx 1)) ) )
   (myElt (3 5 6) 2) => 6  )
```

```lua
]]

```

---

## the expression library

- includes the functions ev and evq
- '#' is the same as 'evq', which will
   evaluate an infix expression
- 'ev' will evaluate its arguments first

```lisp
(progn
   (require 'exp)
   (setq x 14 y 9)
   (print (# x + y*2)) => 22
      (# y =    3)   
   (print y   ) =   > 3
   (print (# `(read) + 12)) ==
   (print (ev (read) '+12)) )
```
- interfaces with lisp to set and read
  variables
