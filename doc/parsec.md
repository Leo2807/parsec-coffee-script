# GrammarGenerator
the GrammarGenerator parsing library--a.k.a "gg"--is based on parser
combinators: the core idea is that parsers are regular coffeescript
functions, and that they can be arranged together with combinators,
i.e. functions which take simple parsers as arguments and return a
more complex parser as a result.

This approach present some interests when compared to parser
generators such as Yacc or Bison:

- A generator gives you some basic operators such as "*", "+", "?",
  "|", but you can't define your own. Since parser combinators are
  regular functions, everyone can write their own.

  For instance, generators typically have some filthy hacks to support
  infix operator definitions in a semi-usable way, letting you define
  associativity and precedence. With parser combinators, you can
  define a proper expression-builder combinator, which will give you
  more control in a cleaner and clearer way.

  Some common idioms, which are encoded in cumbersome ways with
  generators, can be supported natively by a dedicated combinator:
  prefix/infix/suffix operators with precedence and associativity,
  chainable operators (such as a<b<c), comma-separated lists,
  indentation-discarding lists... With combinators you don't have to
  repeat yourself, all recurring patterns can be abstracted away in a
  new combinator.

- A generator creates a fixed parsing program, which can't be modified
  without recompiling it. Parser combinators can be extended on the
  fly, while they are running. If implemented correctly, they can even
  propagate changes lazily and efficiently. This opens the perspective
  of having a source program which modifies its own parser while it's
  being parsed, which is the key for Lisp-style macros.

- Since parsers are regular coffeescript functions, and functions are
  first-class objects, parsers can be mixed freely and fluidly with
  regular code. Side effects, additional condition checking, etc. can
  be put in the grammar definition naturally.




At the base of the system are some very simple, atomic parsers, which
parse the language's atomic elements: identifiers, numbers, keywords
etc. By "parsing", we mean taking a stream of tokens as an input,
returning a syntax tree as an output, and in most cases consumming
some of the tokens at the beginning of the stream.

The simple parsers are used by combinators to build more interesting
parsers. A combinator is a function which takes parsers as arguments,
and return a presumably more complex parser as a result. We will give
a couple of combinator examples below.

A sequence combinator applies two parsers one after the other. If a
parser "id" parses identifiers, and a parser "star" parses only the
keyword "*", then sequence(id, star) parses identifiers followed by a
star.

A choice combinator apply any parser among a list. For instance, if
"star" is the same parser as above, and "plus" parses only the keyword
"+", then choice(star, plus) parses either a "*" or a "+". It can be
combined with the sequence: sequence(id, choice(star, plus)) parses an
identifier followed either by a "*" or a "+". A choice operator needs
a way to choose which parser to apply, when several parsers could
parse successfully.

A list parser allows to repeat a parser: list(star) parses lists of
stars, list(choice(star, plus)) parses lists of stars and pluses such
as "++*+**+++", etc. You can specify a separator, and allow or
disallow empty lists. For instance, list(id, comma) parses lists of
comma-separated identifiers.

After these hand-waving examples, let's come back and define more
precisely what's a parser.

First, we need to define what's a (token) stream. A stream is an
object which can serve elements with or without consumming them. It
has a next() function which removes the first element in the stream
and returns it. peek(n) returns the n-th element of the stream, but
without consumming it. Therefore, successive calls to next() will
return a different token everytime, but successive calls to peek(n)
with the same n will always return the same token. Streams also offer
a save() and a restore() methods, which allow to undo some token
consumption.

(Notes to functional programmers: parser combinators are best known in
Haskell, where they are implemented as purely functional objects: the
streams cannot be modified, and tokens aren't truly consumed. This is
conceptually beautiful, but impractical to implement and use in
anything but Haskell; our streams shamelessly embrace side
effects. Moreover, it is possible to define parser combinators which
can return not only one, but several different parsings, each
potentially consuming a different number of tokens. Since this
feature is rarely necessary, hard to implement efficiently, and makes
it difficult to control a grammar's algorithmic complexity, it has not
been implemented in GrammarGenerator. It is possible to
reintroduce it as a combinator, by using save() and restore())

A parser can either succeed or fail. If it fails, it must not consume
any token from the input stream. Failing is expressed by returning the
special object gg.fail. If a parser succeeds, it can consume some
tokens from the stream, although it doesn't have to.

The two simplest parsers are called zero and one. Zero is a parser
that always fails: as such, it never consumes any token. One is the
parser which always succeeds and never consumes anything. These
parsers aren't very useful by themselves, but can be interesting to
pass as combinator arguments.

One might wonder why these parsers bear those names. It comes from
some of their algebraic features: if you consider the choice combinator
as an addition, and the sequence operator as a multiplication, you'll
find that zero and one behave as the corresponding numbers. Indeed,
for all X:

 * choice(zero, X) == choice(X, zero) == X
 * sequence(one, X) == sequence(X, one) == X
 * sequence(zero, X) == sequence(X, zero) == zero

In theory, you can parse all "reasonnable" languages with zero, one,
choice, sequence, recurrence, and a set of atomic parsers. But gg
tries to focus on practical considerations. Therefore, useful
combinators are implemented efficiently, rather than in terms of
fundamental operators. Moreover, the set of combinators provided by gg
is determined by their usefulness to build up typical programming
language idioms, rather than by their theoretical interest.

we have already presented gg.zero and gg.one, which are parsers rather
than combinators.


# External parser API

## Instantiation

By convention, an instance of class gg.FooBar can be generated with
function gg.fooBar(): "gg.fooBar(a, b, c)" is a shortcut for "new
gg.FooBar(a, b, c)". This convention ligthens the declaration of
complex combinations.


### call(stream)

This method actually runs the parser on a token stream, and returns
the result of the parsing. If the parsing fails, the special object
gg.fail must be returned, and no token must be consummed from the
stream. If the parsing succeeds, the result of the parsing represents
what has been parsed, most likely a syntax tree. This result can be
modified by a builder and transformers, see below.


### setBuilder(f)

If a builder is specified, it is applied to the raw parsing result:

- if it is a function, it takes the raw result as an input, and the
  function's returned value is the final parser's returned value.

- if it is a number n, the raw result is expected to be a list, and the final
  result is the list's n-th element. "p.setBuilder(n)" is equivalent
  to "p.setBuilder((list) -> list[n])"

- if setBuilder receives several numerical arguments, the raw result
  is expected to be a list, and the final result is the list of the
  elements at the corresponding indices. "p.setBuilder(n1, n2, n3)" is
  equivalent to "p.setBuilder((list) -> [list[n1], list[n2], list[n3]])".


### addTransformer()

A transformer is a function applied to the parser's result, after the
builder has been called. The differences between a parser and a
transformer are:

- addTransformer() does not support the shortcuts allowed by
  setBuilder();

- there can be several transformers, whereas there is at most one
  builder;

- the builder is meant to be provided as soon as the parser is
  defined. Transformers can be added later, dynamically, to alter the
  behavior of an existing parser.



## Combinators


### gg.choice([prec_0], child_0, ..., [prec_n], child_n)

Create a choice operator with the children parsers. Each child can be
preceded by a number representing its precedence. If a child has no
explicit precedence, it takes the previously inserted child's
precedence minus one. If the first child has no explicit precedence,
it is set by default at 50.

When several parsers can parse successfully, the one with the highest
precedence is chosen. When two parsers can succeed and both have the
same precedence, the one actually chosen is not specified.

Remark: the operator is not implemented naively: it will NOT try every
child parser in sequence by order of decreasing precedence. gg
combinators maintain some indexing information which allow to
dramatically reduce the possible choices, by looking ahead at the next
token in the stream.

The choice combinator supports an add method:

### add([prec_0], child_0, ..., [prec_n], child_n)

It takes the same arguments as the constructor, but allows to add new
alternatives dynamically. If the addition of new children requires
some internal reorganization, it will be performed lazily, the next
time the combinator actually parses an input. This way, multiple add()
invocations won't be more expensive than a single one.



### gg.list(primary, [separator], [canBeEmpty])

if primary parses elements of type X, then gg.list(primary) parses a
list of Xs. If a separator parser is specified, then it is used between
each element. For instance, gg.list(id) parses a list of identifiers,
separated by nothing but spaces. gg.list(id, comma) parses a list of
comma-separated identifiers.

if canBeEmpty is true, then the parser succeeds and returns [ ]
instead of failing when no primary element can be parsed.

The parser's result, upon success, is the list of elements parsed by
primary. Separator elements, if applicable, are discarded.



### gg.sequence(child_0, ..., child_n)

Parse a sequence of elements, i.e. applies parser child_0 on the
stream, then child_1, etc. The result is the list of all the children
parsers' results.



### gg.maybe(primary)

Behaves as the primary parser, except that it never fails. It succeed
and returns null if primary fails to parse. "gg.maybe(X)" is
functionally equivalent to "gg.choice(X, gg.one)"



### gg.if(trigger, primary, whenNotTriggered)

first calls parser "trigger". If it succeeds, calls parser "primary"
and returns its result. If "trigger" fails, returns the constant
"whenNotTriggered".

"gg.if(T, P)" parses the same inputs as "gg.maybe(gg.sequence(T, P))",
but is handy to easily build the result. The equivalent parser, which
returns the correct result, is as follows

gg.choice(
    gg.sequence(T,P).setBuilder(1),
    gg.wrap(gg.one).setBuilder(->whenNotTriggered)
)



### gg.liftedFunction(f)

Change a function, which takes a token stream as an argument, into a
parser. This is necessary to put a function in a combinator. For
instance, the following snippets defines a naive sequence operator (it
is grossly inefficient, and doesn't behave correctly when it faces
incorrect inputs):

naiveSequence =
    (children...) -> gg.liftedFunction(
        (stream) -> child.call(stream) for child in children
    )

It is more idiomatic to call "gg.lift f" than "gg.liftedFunction f".


### gg.wrap(parser)

Simply calls parser, and return its result. The main interest of
wrapping a parser is to give it a custom builder:
gg.wrap(X).setBuilder(f) will not modify the parser X, whereas
X.setBuilder(f) obviously would.


### gg.filter(predicate)



## Lifting

some basic coffeescript objects have a "natural" meaning, when used
where a parser is expected. strings, lists, functions, 0 and 1 can be
lifted, i.e. transformed into parsers.

- gg.lift("keyword") is equivalent to gg.keyword("keyword"), it
  returns the parser which parses the keyword "keyword".
- gg.lift([a, b, c]) is equivalent to gg.sequence(a, b, c).
- gg.lift(f), where f is a function, is equivalent to
  gg.liftedFunction(f).
- gg.lift(0) == gg.zero.
- gg.lift(1) == gg.one.
- gg.lift(p) == p if p is already a parser.

Moreover, whenever a parser constructor or method expects a parser
parameter, it automatically lifts it to turn it into a parser.

For instance, a complete specification of a parser for a list of comma
separated identifiers is "gg.list(gg.id, gg.keyword(','))". However,
thanks to lifting, it can be written simply "gg.list(gg.id, ',')".


### gg.expr(primary)

This is by far the most complex and most specialized parser provided
by gg. It allows to build an expression parser, with prefix, infix and
suffix operators, around a primary parser. the result of "gg.expr(X)"
is a parser equivalent to "X". However, it supports methods
addPrefix(), addInfix() and addSuffix() which allow to modify it.

### addPrefix({parser, [prec], builder})

add a prefix operator, with the specified precedence. If the prefix
parser returns "P", and the expression to which the prefix applies is
"E", then the result is "builder(P, E)".

Example:

primary = gg.keyword("N").setBuilder( -> "NNN")
e       = gg.expr(gg.keyword "N")
e.addPrefix {parser: keyword("-"), builder: (p, x) -> "minus "+x}

The parser e will parse successfully "-N" and return "minus
NNN". Notice that thanks to lifting, the last line could have been
shortened as:

e.addPrefix { parser:"-", builder: (_, x) -> "minus "+x }

addInfix({parser, [prec], [assoc], builder})

addSuffix({parser, [prec], builder)



## Creating efficient new combinators

Until now, implementation details have been spared, as we focused on
combinator users, rather than combinator writers. However, for parsing
to remain efficient, some non-trivial internal mechanisms are
required.

- catcodes

- epsilon productions

- change notification

- reindexing

- protected API, to extend existing parser classes
