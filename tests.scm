(load "./csf.scm")

(define (format str)
  (let ([fmt (generator formatter)] [parts '()])
    (string-for-each
      (lambda (c)
        (let ([res (fmt c)])
          (unless (generator-eof? res)
            (set! parts (cons res parts)))))
      str)
    ; (set! parts (cons (fmt #f) parts))
    (apply string-append (reverse parts))))

(define (without-output-to-string body)
  (body)
  "")

(define (test input expected)
  (define res)
  (define logged
    (with-output-to-string
      (lambda ()
        (set! res (format input)))))
  (unless (string=? expected res)
    (display "expected:\n" (current-error-port))
    (display expected (current-error-port))
    (display "\ngot:\n" (current-error-port))
    (display res (current-error-port))
    (display "\nlogged:\n" (current-error-port))
    (display logged (current-error-port))))

(test "(call\nsome\n    thing)"
      "(call\n  some\n  thing)")

(test "(call some\nthing)"
      "(call some\n      thing)")

(test "(call some\n(call two))"
      "(call some\n      (call two))")

(test "(call some\n(call\ntwo)\nbar)"
      "(call some\n      (call\n        two)\n      bar)")

(test "(call (call)\n5)"
      "(call (call)\n      5)")

(test "(define states '())"
      "(define states '())")

(test "(ignore
         #\\)
         a)"
      "(ignore\n  #\\)\n  a)")

(test "(cond\n[#f 5]\n[else 6])"
      "(cond\n  [#f 5]\n  [else 6])")

(test
  (string-append
    "(cond\n"
    "[#f\n"
    "5]\n"
    "[else\n"
    "6])")
  (string-append
    "(cond\n"
    "  [#f\n"
    "   5]\n"
    "  [else\n"
    "    6])"))

(test
  (string-append
    "(cond\n"
    "[(mt)\n"
    "5])")
  (string-append
    "(cond\n"
    "  [(mt)\n"
    "   5])"))

(test "(a)\n(a)" "(a)\n(a)")

(test
  (string-append
    "(cond\n"
    "  [\"abc)\" 5]\n"
    "[else (display\n"
    "   5)])")
  (string-append
    "(cond\n"
    "  [\"abc)\" 5]\n"
    "  [else (display\n"
    "          5)])"))

(test
  (string-append
    "(letrec ([f\n"
    "(lambda (x)\n"
    "5)]))")
  (string-append
    "(letrec ([f\n"
    "           (lambda (x)\n"
    "             5)]))"))

(test
  (string-append
    "(if (null? xs)\n"
    "#t\n"
    "#f)")
  (string-append
    "(if (null? xs)\n"
    "  #t\n"
    "  #f)"))

