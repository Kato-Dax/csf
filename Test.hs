{-# LANGUAGE MultilineStrings, BlockArguments, LambdaCase #-}
module Main where

import Data.Traversable
import Data.Functor

import Control.Monad

import Text.Printf

import System.Environment
import System.Process
import System.Exit
import System.IO

data TestCase = TestCase { input :: String, expected :: String }

testcases :: [TestCase]
testcases =
  [ TestCase
    """
    (call
    some
        thing)
    """
    """
    (call
      some
      thing)
    """
  , TestCase
    """
    (call some
    thing)
    """
    """
    (call some
          thing)
    """
  , TestCase
    """
    (call some
    (call two))
    """
    """
    (call some
          (call two))
    """
  , TestCase
    """
    (call some
    (call
    two)
    bar)
    """
    """
    (call some
          (call
            two)
          bar)
    """
  , TestCase
    """
    (call (call)
    5)
    """
    """
    (call (call)
          5)
    """
  , TestCase "(define states '())" "(define states '())"
  , TestCase
    """
    (ignore
      #\\)
      a)
    """
    """
    (ignore
      #\\)
      a)
    """
  , TestCase
    """
    (cond
    [#f 5]
    [else 6])
    """
    """
    (cond
      [#f 5]
      [else 6])
    """
  , TestCase
    """
    (cond
    [#f
    5]
    [else
    6])
    """
    """
    (cond
      [#f
       5]
      [else
        6])
    """
  , TestCase
    """
    (cond
    [(mt)
    5])
    """
    """
    (cond
      [(mt)
       5])
    """
  , TestCase
    """
    (a)
    (a)
    """
    """
    (a)
    (a)
    """
  , TestCase
    """
    (cond
      ["abc)" 5]
    [else (display
       5)])
    """
    """
    (cond
      ["abc)" 5]
      [else (display
              5)])
    """
  , TestCase
    """
    (letrec ([f
    (lambda (x)
    5)]))
    """
    """
    (letrec ([f
               (lambda (x)
                 5)]))
    """
  , TestCase
    """
    (if (null? xs)
    #t
    #f)
    """
    """
    (if (null? xs)
      #t
      #f)
    """
  , TestCase "(,(a))" "(,(a))"
  , TestCase "(`(a))" "(`(a))"
  ]

main = run =<< getArgs

run args = do
  let spawnFormatter = do
        (Just stdin, Just stdout, _, procHandle) <- case args of
          [] -> do
            hPutStrLn stderr . printf "usage: %s <formatter-cmd> [formatter-args]" =<< getProgName
            exitFailure
          formatterCmd:formatterArgs -> do
            createProcess (proc formatterCmd formatterArgs){ std_in = CreatePipe, std_out = CreatePipe }
        pure (stdin, stdout, procHandle)

  void $ for testcases $ \(TestCase { input, expected }) -> do
    (stdin, stdout, procHandle) <- spawnFormatter
    hPutStr stdin input
    hClose stdin

    actual <- hGetContents stdout
    when (actual /= expected) do
      hPutStrLn stderr $ printf "Input:\n%s\nExpected:\n%s\nActual:\n%s\n" input expected actual
      exitFailure

    waitForProcess procHandle >>= \case
      ExitSuccess -> pure ()
      failure -> do
        print failure
        exitWith failure

