
#-------------------------------------------------------------------------------
# Enable this to print array elements.
if true
    Array.prototype.toString = -> '[ ' + (@join ', ') + ' ]'

#-------------------------------------------------------------------------------
# Enable this to prevent function printing from dumping whole sources
if true
    Function.prototype.toString = -> "<FUNCTION>"

#-------------------------------------------------------------------------------
# Enable this to print objects content.
if true
    Object.prototype.toString = ->
        '{' + (("#{k}: #{v}" for k, v of @).join ', ') + '}'

#-------------------------------------------------------------------------------
# Imports
cs = require "../src/CoffeeScriptParser"
gg = require "../src/GrammarGenerator"
{ print, error, inspect } = require 'util'
{ tree, toIndentedString, equal:astEqual } = require '../src/Tree'

#-------------------------------------------------------------------------------
# set of source strings, indexed by names, to be run as tests.
# Each string must be a valid coffeescript block, unless its
# name starts with "fail_": in this case it must *not* parse
# correctly.
#-------------------------------------------------------------------------------
src = { }

#-------------------------------------------------------------------------------
# set of expected ASTs, indexed by names. An AST is optional
# in a test, but if there is one, then the result of the parser
# must match.
#-------------------------------------------------------------------------------
ast = { }

#-------------------------------------------------------------------------------
#--- TESTS ---------------------------------------------------------------------
#-------------------------------------------------------------------------------

src.x1='x[1]'

# basic identifier
src.id = "foo"

# Don't accept keywords as id
src.fail_id = "if"

# function calls
src.calls = """
    foo()
    foo(bar)
    foo(bar, bar)
    foo bar
    foo bar, bar
    foo foo bar, bar
"""

# no space before function args
src.fail_call = "foo (1,2,3)"

# anonymous functions
src.lambda1 = """
    (x) -> x
    (x, y) -> x+y
    -> meh
    (x) -> (y) -> curry
"""

ast.lambda1 = [
    tree 'Function', [tree 'Id', 'x'], [tree 'Id', 'x']
    tree 'Function',
        [(tree 'Id', 'x'), (tree 'Id', 'y')],
        [tree 'Op', '+',
            (tree 'Id', 'x'),
            (tree 'Id', 'y')]
    tree 'Function', [ ], [tree 'Id', 'meh']
    tree 'Function', [tree 'Id', 'x'],
        [tree 'Function', [tree 'Id', 'y'],
            [tree 'Id', 'curry']]]

src.lambda2 = '''
  ->
  (a) ->
  () ->
  -> b()
  ->
     c()
     d()
  (e) ->
     f()
'''

ast.lambda2 = [
    (tree 'Function', [], []),
    (tree 'Function', [tree 'Id', 'a'], []),
    (tree 'Function', [], []),
    (tree 'Function', [], [tree 'Call', (tree 'Id', 'b'), []]),
    (tree 'Function', [], [
        (tree 'Call', (tree 'Id', 'c'), []),
        (tree 'Call', (tree 'Id', 'd'), [])]),
    (tree 'Function', [tree 'Id', 'e'],
        [(tree 'Call', (tree 'Id', 'f'), [])])]

src.lambda3 = '''
    first = (a, b...) -> a
    last  = (a..., b) -> b
'''

ast.lambda3 = [
    (tree 'Op', '=',
        (tree 'Id', 'first'),
        (tree 'Function', [(tree 'Id', 'a'), (tree 'Id', 'b')], [tree 'Id', 'a'], 1)),
    (tree 'Op', '=',
        (tree 'Id', 'last'),
        (tree 'Function', [(tree 'Id', 'a'), (tree 'Id', 'b')], [tree 'Id', 'b'], 0))]

src.fail_lambda1 = '(a, b..., c...) -> "no more than one splatted arg"'

# super invocations
src.super = """
    super
    super 1, 2, 3
    super(4,5,6)
"""

ast.super = [
    tree 'Super'
    tree 'Call', (tree 'Super'), [
        (tree 'Number', 1)
        (tree 'Number', 2)
        (tree 'Number', 3) ]
    tree 'Call', (tree 'Super'), [
        (tree 'Number', 4)
        (tree 'Number', 5)
        (tree 'Number', 6) ] ]


# as for functions, no space before args in parentheses
src.fail_super = "super (1,2)"

src.splat = """
    f x...
    (x...) -> y
    (a,b...,c) ->
"""

ast.splat = [
    tree 'Call', (tree 'Id', 'f'), [
        tree 'Op', '...', (tree 'Id', 'x') ]
    tree 'Function',
        [tree 'Id', 'x']
        [tree 'Id', 'y'], 0
    tree 'Function', [
        (tree 'Id', 'a')
        (tree 'Id', 'b')
        (tree 'Id', 'c') ], [ ], 1 ]


# Splats not accepted except as args or params
src.fail_splat = """
    x...
"""

# at-sign
src.at = """
    x1 @
    @x2
    @
    @x3(a, @b, @c)
    @x4 a, @b, @c
    @[1]
"""

src.fail_at = """
    @@
"""

src.accessor = """
    x[1]
    x[1][2][3]
    x.y
    x.class
    x[1..10]
    x[1...10]
"""

src.array_arg = """
    f [1,2]
    g([2])
"""

# multiple values -> index forbidden
src.fail_array = """
    x[1,2]
"""

# This is accepted because it's a list arg, not an index
# TODO: doesn't work without parentheses, indentation handling also broken.
src.not_an_accessor = """
    x( [a,b,c])
"""

src.array = """
    a1=[a, b, c]
    a2 = [d, e,
        f]
    [g,
    h,
    i]
    [j, k,
        l, m,
    n, o]
    [p, q,]
    [r,
    ]
    [ f x
      a
       b
      c, d]
"""

src.object1 = """
obj = { a:1; b:{c:1} }
"""

src.object2 = """
obj = {
    a:1
    b:2,
    c:3
    d:{e:4; f:5}
}
"""

ast.object2 = [
    tree 'Op', '=', (tree 'Id', 'obj'),
        tree 'Object', [
            [ 'a', (tree 'Number', 1) ]
            [ 'b', (tree 'Number', 2) ]
            [ 'c', (tree 'Number', 3) ]
            [ 'd',  tree 'Object', [
                [ 'e', (tree 'Number', 4) ]
                [ 'f', (tree 'Number', 5) ]]]]]

src.object3 = '''
{
    a: {
        b: {
            c:1
        d:2 } } }
'''

src.object4 = '''
{
    a:
        b:
            c:1
        d:2 }
'''

src.op1 = '1+2'
src.op2 = '1 + 2'
src.op3 = '1+2+3'
src.op4 = '1+2*3'
src.op5 = '1+2+3+4'
src.op6 = '1+2-3+4-5'

src.operators = """
    a + b * c
    d ? e ? f
    d? ? e? ? f?
    a++
    ++b
    a++ + ++b
    ++--x--++
    -1 - - --2
"""

src.if1 = """
    if cond
        a
        b
        c
"""

src.if2 = """
    if cond then a; b; c
"""

src.if3 = """
    doit() if condition
"""

src.if4 = """
    doit() if cond1 if cond2
"""

ast.if4 = [
    (tree 'If', (tree 'Id', "cond2"), [
        (tree 'If', (tree 'Id', "cond1"), [
            (tree 'Call', (tree 'Id', "doit"), [ ] )])])]

src.if5 = """
    f arg if cond
"""

ast.if5 = [
    (tree 'If', (tree 'Id', "cond"), [
        (tree 'Call', (tree 'Id', "f"), [
            (tree 'Id', "arg") ] )])]

src.if6 = """
    f arg1, arg2 if cond
"""

ast.if6 = [
    (tree 'If', (tree 'Id', "cond"), [
        (tree 'Call', (tree 'Id', "f"), [
            (tree 'Id', "arg1"),
            (tree 'Id', "arg2") ])])]

src.if7 = 'f(a, b if cond)'

ast.if7 = [
    (tree 'Call', (tree 'Id', "f"), [
        (tree 'Id', "a"),
        (tree 'If',
            (tree 'Id', "cond"), [
                (tree 'Id', "b") ])])]
src.if8 = 'f a, b if cond'

ast.if8 = [
    (tree 'If',
        (tree 'Id', "cond"), [
            (tree 'Call', (tree 'Id', "f"), [
                (tree 'Id', "a"),
                (tree 'Id', "b") ])])]

src.for1 = """
    for i in array
        body()
"""

ast.for1 = [
    (tree 'For', [(tree 'Id', "i")], 'in', (tree 'Id', "array"), [
        (tree 'Call', (tree 'Id', "body"), [] )])]

src.for2 = "a=b for c in d"

ast.for2 = [
    (tree 'For', [(tree 'Id', "c")], 'in',  (tree 'Id', "d"), [
        (tree 'Op', '=',  (tree 'Id', "a"),  (tree 'Id', "b"))])]

src.for3 = "a=(b for c in d)"

ast.for3 = [
    (tree 'Op', '=', (tree 'Id', "a"),
        (tree 'For', [(tree 'Id', "c")], 'in',  (tree 'Id', "d"),
            [(tree 'Id', "b")]
        )
    )
]


src.for4 = """
    for own k, v of map when cond
        f(k, v)
"""

src.for5 = """
    for x, i in list by 2
        f(i, x)
    for x, i in list by 2 when cond
        f(i, x)
    for x, i in list when cond by 2
        f(i, x)
    for x, i in list when cond
        f(i, x)
"""

src.fail_for1 = "for k, v of map by 42"
src.fail_for2 = "for own i of in list"
src.fail_for3 = "for a, b, c of map"
src.fail_for4 = "for of map"

src.while1 = """
    while cond
        body
"""

ast.while1 = [
    (tree 'While', (tree 'Id', "cond"), [
        (tree 'Id', "body")])]

src.while2 = """
    while cond when guard
        body
"""

ast.while2 = [
    (tree 'While', (tree 'Id', "cond"), (tree 'Id', "guard"), [
        (tree 'Id', "body")])]

src.while3 = """
    until cond when guard
        body
"""

ast.while3 = [
    (tree 'While',
        (tree 'Op', '!', (tree 'Id', "cond")), (tree 'Id', "guard"), [
            (tree 'Id', "body")])]

src.while4 = """
    loop
        body
"""

ast.while4 = [
    (tree 'While', (tree 'True'), [
        (tree 'Id', "body")])]

src.while5 = """
    x++ while x<y
"""

# TODO associates at right instead of left
src.while6 = """
    expr while cond1 while cond2
"""

src.while7 = """
    expr while cond1 while cond2 when guard2
"""

src.while8 = """
    (expr while cond1 when guard1) while cond2 when guard2
"""

src.string1 = """
    x = "string"
"""

src.string2 = '''
    x = "text#{symbol}textAgain"
'''

src.string3 = '''
    x = "t1#{esc1 "t2#{esc2}*t2"}t1"
'''

src.cmp1 = '''
    x<1
    x>2
    x==3
    x is 4
'''

src.cmp2 = '''
    w<x<y<z
'''

ast.cmp2 = [
    (tree 'Op', '<',
        (tree 'Op', '<',
            (tree 'Op', '<',
                (tree 'Id', 'w'),
                (tree 'Id', 'x')),
            (tree 'Id', 'y')),
        (tree 'Id', 'z')) ]


src.eq1 = '''a=b=c''' # also tests right-assoc

ast.eq1 = [
    (tree 'Op', '=',
        (tree 'Id', 'a'),
        (tree 'Op', '=',
            (tree 'Id', 'b'),
            (tree 'Id', 'c')))]


src.regex1 = '''
    r1 = /foo/
    r2 = /bar/ig
    r3 = ///gnu///
    '''
src.regex2 = '''
    r = ///a#{b}c///
'''


#-------------------------------------------------------------------------------
#--- END OF TESTS --------------------------------------------------------------
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# Determine the set of test names to run
# src: test suite
# regexes: list of regexes, presumably passed from command line
#-------------------------------------------------------------------------------
getTestsToRun = (src, regexes) ->
    tests = { }
    if regexes.length is 0
        (tests[name] = true) for name of src
    else
        used_regexes = { }
        for name of src
            for regex in regexes
                if name.match regex
                    tests[name] = true
                    used_regexes[regex]  = true
                    break
        for regex in regexes
            unless used_regexes[regex]
                print "Warning, unused regex '#{regex}'\n"
    return tests

#-------------------------------------------------------------------------------
# Run one test.
# name: name of the test. The test must fail iff the name starts with "fail_".
# src:  source string of the test.
# ast:  AST that must be produced as a result (optional).
# logger: what to do if a test fails.
#-------------------------------------------------------------------------------
runTest = (name, src, ast, logger) ->
    logger ?= print
    print "\n***** Test #{name} *****\n#{src}\n"
    try
        t = cs.parse src
    catch e
        logger "Exception while running test '#{name}': #{e}\n#{e.stack}\n"
        return false

    hasFailed  = t is gg.fail
    shouldFail = name.match /^fail_/
    if ast?
        astFailed = not astEqual ast, t
        hasFailed ||= astFailed
        #if astEqual(a,t) != (a.toString()==t.toString())
        #    print "\nEquality test failed for #{a} and #{t}!!!\n"
    else astFailed = false

    if hasFailed and shouldFail
        print "\n#{name} input:\n#{src}\n\nCompilation of #{name} failed, as expected\n"
        return true
    else if astFailed and not shouldFail
        logger "Failure, invalid tree for src.#{name}\nexp: #{ast}\ngot: #{t}\nsrc: #{src}"
        return false
    else if hasFailed and not shouldFail
        logger "Failure, cannot parse src.#{name}"
        return false
    else if not hasFailed and shouldFail
        logger "Test #{name} should have failed"
        return false
    else if not hasFailed and not shouldFail
        print "\n#{name} input:\n#{src}\n\n#{name} result:\n#{toIndentedString t}\n"
        return true

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main = (args) ->

    log = [ ]
    logger = (msg) ->
        print "\n>>>>>>>>> ERROR: #{msg}\n"
        log.push msg

    total = success = 0
    for name of getTestsToRun(src, args)
        total++
        r = runTest name, src[name], ast[name], logger
        success++ if r
    if total == success
        print "\nAll #{total} tests passed successfully\n"
    else
        print """

           ------------------------------------------------------------------
           ------------------------------------------------------------------
           -- #{success} successes and #{total-success} failures out of #{total} tests
           ------------------------------------------------------------------
           ------------------------------------------------------------------

           #{log.join '\n\n'}

           """

main (process.argv[2...])

#TODO: src finishing with a comment
