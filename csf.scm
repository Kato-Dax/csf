#!/usr/bin/env -S scheme --program
(import (chezscheme))

(define-record-type (generator-eof make-generator-eof generator-eof?) (fields))
(define eof (make-generator-eof))
(define (generator body)
  (define waiting #f)
  (define spot #f)
  (define (yield value)
    (call/cc
      (lambda (k)
        (set! spot k)
        (let ([f waiting])
          (set! waiting #f)
          (f value)))))
  (lambda (input)
    (call/cc
      (lambda (k)
        (unless body (k eof))
        (set! waiting k)
        (when spot
          (let ([f spot])
            (set! spot #f)
            (k (f input))))
        (begin
          (body yield input)
          (set! spot #f)
          (set! waiting #f)
          (set! body #f)
          eof)))))

(define-record-type (in-form-name make-in-form-name in-form-name?) (fields depth ident))
(define-record-type (after-form-name make-after-form-name after-form-name?) (fields form-name depth))
(define-record-type (in-indented make-in-indented in-indented?) (fields depth))
(define-record-type (after-hash make-after-hash after-hash?) (fields))
(define-record-type (after-hash-backslash make-after-hash-backslash after-hash-backslash?) (fields))
(define-record-type (in-string make-in-string in-string?) (fields))
(define-record-type (string-escape make-string-escape string-escape?) (fields))
(define-record-type (in-comment make-in-comment in-comment?) (fields))

(define special-forms '("define" "if" "let" "let*" "letrec" "case" "cond" "lambda" "set!" "unless" "when"))

(define-record-type (line-info make-line-info line-info?) (fields depth all-whitespace))

(define (formatter yield first-char)
  (define (update-line-info line-info chars)
    (let ([chars (cond [(string? chars) (string->list chars)] [(char? chars) `(,chars)] [else chars])])
      (make-line-info
        (fold-left
          (lambda (depth c) (if (char=? c #\newline) 0 (+ 1 depth)))
          (line-info-depth line-info)
          chars)
        (fold-left
          (lambda (all-ws c) (or (char=? c #\newline) (and all-ws (char-whitespace? c))))
          (line-info-all-whitespace line-info)
          chars))))

  (define (out parts part)
    (yield (apply string-append
                  (map (lambda (s)
                         (cond
                           [(string? s) s]
                           [(char? s) (list->string `(,s))]
                           [else (list->string s)]))
                       (reverse (cons part parts))))))

  (let loop ([states `(,(make-in-indented 0))] [line-info (make-line-info 0 #f)] [parts '()] [c first-char])
    (define state (car states))
    (define (next states part)
      (loop states (update-line-info line-info part) '() (out parts part)))
    (define (again states part)
      (loop states (update-line-info line-info part) (cons part parts) c))
    (define (push state)
      (cons state states))
    (define (pop) (if (null? (cdr states)) states (cdr states)))
    (define (set state)
      (cons state (pop)))

    (define (on-in-string-state)
      (next
        (case c
          [#\" (pop)]
          [#\\ (push (make-string-escape))]
          [else states])
        c))

    (define (on-in-indented-state)
      (let ([missing-depth (- (in-indented-depth state) (line-info-depth line-info))])
        (cond
          [(char=? #\space c)
           (if (and (>= 0 missing-depth) (line-info-all-whitespace line-info))
             (next states "")
             (next states " "))]
          [(char-whitespace? c)
           (next states c)]
          [(char=? c #\;)
           (next (push (make-in-comment)) ";")]
          [else
            (let* ([prefx (if (or (>= 0 missing-depth) (not (line-info-all-whitespace line-info)))
                            ""
                            (list->string (map (lambda (_) #\space) (iota missing-depth))))]
                   [prefix-and-c (string-append prefx (list->string `(,c)))])
              (case c
                [#\#
                 (next (push (make-after-hash)) prefix-and-c)]
                [#\"
                 (next (cons (make-in-string) states) prefix-and-c)]
                [else
                  (case c
                    [#\(
                     (next
                       (push (make-in-form-name (+ (string-length prefx) (line-info-depth line-info)) '()))
                       prefix-and-c)]
                    [#\[
                     (next
                       (push (make-in-form-name (+ (string-length prefx) (line-info-depth line-info)) '()))
                       prefix-and-c)]
                    [#\) (next (pop) prefix-and-c)]
                    [#\] (next (pop) prefix-and-c)]
                    [else (next states prefix-and-c)])]))])))

    (define (on-after-form-name-state)
      (let ([form-name (after-form-name-form-name state)])
        (cond
          [(char=? c #\space)
           (next states "")]
          [(char=? c #\;)
           (next (push (make-in-comment)) ";")]
          [(char=? c #\newline)
           (next
             (set (make-in-indented (+ 2 (after-form-name-depth state))))
             (string-append form-name "\n"))]
          [else
            (let* ([gap (if (or (char=? c #\)) (char=? c #\]) (= 0 (string-length form-name))) "" " ")]
                   [indentation (if (member form-name special-forms)
                                  (+ 2 (after-form-name-depth state))
                                  (+ (string-length form-name) (string-length gap) (line-info-depth line-info)))])
              (again (set (make-in-indented indentation)) (string-append form-name gap)))])))

    (when c
      (cond
        [(in-form-name? state)
         (let* ([function-name (list->string (reverse (in-form-name-ident state)))])
           (if
             (member c (list #\newline #\space #\( #\[ #\" #\) #\] #\# #\;))
             (again (set (make-after-form-name function-name (in-form-name-depth state))) "")
             (next (set (make-in-form-name (in-form-name-depth state) (cons c (in-form-name-ident state)))) "")))]
        [(after-form-name? state) (on-after-form-name-state)]
        [(in-comment? state)
         (case c
           [#\newline (again (pop) "")]
           [else
             (next states c)])]
        [(in-indented? state) (on-in-indented-state)]
        [(after-hash? state)
         (case c
           [#\\ (next (set (make-after-hash-backslash)) "\\")]
           [else (next (pop) c)])]
        [(after-hash-backslash? state)
         (next (pop) c)]
        [(in-string? state) (on-in-string-state)]
        [(string-escape? state)
         (next (pop) c)]
        [else
          (error 'formatter "INTERNAL ERROR: unknown state")]))))

(define (format-port in out)
  (let ([fmt (generator formatter)])
    (let loop ([c (get-char in)])
      (cond
        [(eof-object? c)
         (flush-output-port out)]
        [else
          (put-string-some out (fmt c))
          (loop (get-char in))]))))

(format-port (current-input-port) (current-output-port))

