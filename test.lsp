(namespace into test

(de app (a b)
   (cond
      (null a) b
    (cons (car a) (app (cdr a) b)) )  )

(setq map (closure (fn l)
   (cond l
      (cons (fn (car l))
         (map fn (cdr l)) )
      () )  ))

())
