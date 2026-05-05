# Chez Scheme Formatter
*csf* is a code formatter for scheme. <br>
It's written in [chez scheme](https://cisco.github.io/ChezScheme/) and only tested against Chez Scheme code.

## Usage
*csf* reads from stdin and outputs formatted code to stdout.

```bash
./csf.scm < unformatted.scm > formatted.scm
```

I recommend letting your editor know how to use *csf*.

### In Neovim:
```lua
vim.opt.formatprg = "csf.scm" -- If you put csf.scm into your PATH
-- see :help formatprg
```

## Installation
*csf* is implemented in a single file without any dependencies [`csf.scm`](./csf.scm).
As long as you have Chez Scheme installed, it should just work.

If the shebang in csf.scm doesn't work, you can call it directly:
`scheme --program ./csf.scm`.

## Behaviour
*csf* is very simple, it doesn't change anything in your code besides indentation.

*csf*s behaviour also matches the behaviour of the vim auto-indent feature.

### Examples
```scheme
(for-each
(lambda (x)
        (display (+ 2 x)))
      (iota 8))

; =>

(for-each
  (lambda (x)
    (display (+ 2 x)))
  (iota 8))
```

```scheme
(letrec ([a 0]
[b 2]
[c 3]
               [d 4])
(+ a
b
c
d))

; =>

(letrec ([a 0]
         [b 2]
         [c 3]
         [d 4])
  (+ a
     b
     c
     d))
```

```scheme
(case #\c
    [#\a
    0]
    [#\b
    1]
    [#\c
    2]
    [else
    100])

; =>
(case #\c
  [#\a
   0]
  [#\b
   1]
  [#\c
   2]
  [else
    100]) ; you might expect `100` to be aligned with the expressions in
          ; the other cases (`0`, `1`, `2`). Because `else` is not treated
          ; specially by csf, [else 100] looks just like a function call 
          ; and is therefore indented like one.
          ; Meanwhile [#\a 0] is obviously not a function call and 
          ; special behaviour applies.
```

```scheme
(write ((const 10)
   8))
; =>
(write ((const 10)
        8)) ; even though the 8 is an argument to a function call,
            ; it is not indented like one. I would have expected this:
                                              (write ((const 10)
                                                        8))
            ; I don't like this behaviour, but vim does it like this
            ; and i don't want to deviate.
```

