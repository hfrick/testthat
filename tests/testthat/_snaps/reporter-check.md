# basic report works

    [ FAIL 4 | WARN 1 | SKIP 3 | PASS 1 ]
    
    == Skipped tests ===============================================================
    * empty test (2)
    * skip (1)
    
    == Warnings ====================================================================
    -- Warning (tests.R:49:3): warnings get backtraces -----------------------------
    def
    Backtrace:
     1. f() reporters/tests.R:49:2
    
    == Failed tests ================================================================
    -- Failure (tests.R:12:3): Failure:1 -------------------------------------------
    FALSE is not TRUE
    
    `actual`:   FALSE
    `expected`: TRUE 
    -- Failure (tests.R:17:3): Failure:2a ------------------------------------------
    FALSE is not TRUE
    
    `actual`:   FALSE
    `expected`: TRUE 
    Backtrace:
        x
     1. \-f() reporters/tests.R:17:2
     2.   \-testthat::expect_true(FALSE) reporters/tests.R:16:7
    -- Error (tests.R:23:3): Error:1 -----------------------------------------------
    Error in `eval(code, test_env)`: stop
    -- Error (tests.R:31:3): errors get tracebacks ---------------------------------
    Error in `h()`: !
    Backtrace:
        x
     1. \-f() reporters/tests.R:31:2
     2.   \-g() reporters/tests.R:27:7
     3.     \-h() reporters/tests.R:28:7
    
    [ FAIL 4 | WARN 1 | SKIP 3 | PASS 1 ]

# doesn't truncate long lines

    [ FAIL 1 | WARN 0 | SKIP 0 | PASS 0 ]
    
    == Failed tests ================================================================
    -- Failure (long-test.R:2:3): That very long test messages are not truncated because they contain useful information that you probably want to read --
    Failure has been forced
    
    [ FAIL 1 | WARN 0 | SKIP 0 | PASS 0 ]

# always shows summary

    [ FAIL 0 | WARN 0 | SKIP 0 | PASS 7 ]

# shows warnings when not on CRAN

    [ FAIL 4 | WARN 1 | SKIP 3 | PASS 1 ]
    
    == Skipped tests ===============================================================
    * empty test (2)
    * skip (1)
    
    == Warnings ====================================================================
    -- Warning (tests.R:49:3): warnings get backtraces -----------------------------
    def
    Backtrace:
     1. f() reporters/tests.R:49:2
    
    == Failed tests ================================================================
    -- Failure (tests.R:12:3): Failure:1 -------------------------------------------
    FALSE is not TRUE
    
    `actual`:   FALSE
    `expected`: TRUE 
    -- Failure (tests.R:17:3): Failure:2a ------------------------------------------
    FALSE is not TRUE
    
    `actual`:   FALSE
    `expected`: TRUE 
    Backtrace:
        x
     1. \-f() reporters/tests.R:17:2
     2.   \-testthat::expect_true(FALSE) reporters/tests.R:16:7
    -- Error (tests.R:23:3): Error:1 -----------------------------------------------
    Error in `eval(code, test_env)`: stop
    -- Error (tests.R:31:3): errors get tracebacks ---------------------------------
    Error in `h()`: !
    Backtrace:
        x
     1. \-f() reporters/tests.R:31:2
     2.   \-g() reporters/tests.R:27:7
     3.     \-h() reporters/tests.R:28:7
    
    [ FAIL 4 | WARN 1 | SKIP 3 | PASS 1 ]

