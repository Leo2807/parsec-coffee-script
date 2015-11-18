# Notes
## Points to raise:

check whether there isn't some inconsitanecy in the way || and binary ? combine.

== and != chains can't be mixed with inequality chains.

questionnable lack of relative precedence between || and &&, | and &.

I miss a do/while, although indentation might be tricky.

No interpolation in object literal keys { "#{foo}": bar }.

f(
  foo bar,
  gnu
)
translates to f(foo(bar, gnu)), spontaneously reads as f(foo(bar), gnu)

## Todo:

Detect circular dependencies in notification chains, esp. if they
coincide with left recursions that won't work.

let flat operators work by families, e.g. for "x<y>z" chains.

interpolated strings parsing

support for ///.../// regexps, remove interpolation in /.../

lifting strings into token streams when applicable?
