% A taste of dependent types

Keegan McAllister

May 15, 2015

<div style="padding-top: 40px; font-size: 60%">
<p>Navigate with ← and → keys, or <a href="#" id="view-all">view all slides</a>.</p>
<p>Available at <a href="http://kmcallister.github.io/talks/rust/2015-dependent-types/slides.html"><code>kmcallister.github.io</code></a></p>
</div>

# Dependent types

Types are first-class values

Argument type can *depend on* value of prior argument

```rust
fn foo(T: type, n: usize, v: &Vec(T, n)) {
    ...
}
```

Why might we want this in Rust?

* **Simplify** the compile-time language
* **Prove correctness** of programs and APIs
* **Eliminate overhead** of run-time checks
* Clean up the syntax — no more `f::<T>(x)`

# Refinement types

Known in industry as *design by contract*.

Fits perfectly in Rust syntax!

```rust
fn index(T: type, x: &[T], i: usize) -> &T
    where i < x.len()
{
    ...
}
```

# Data invariants

This binary tree is always in search order:

```rust
fn range(lo: isize, hi: isize) -> type {
    those x: isize where lo <= x && x < hi
}

enum Tree(lo: isize, hi: isize) {
    Empty,
    Node {
        val: range(lo, hi),
        left: Tree(lo, val),
        right: Tree(val, hi),
    },
}
```

# Implementing refinements

Subtyping based on logical implication is undecidable.

Compiler asks an &ldquo;off-the-shelf&rdquo; theorem prover.

Answer is &ldquo;yes&rdquo;, &ldquo;no&rdquo;, or &ldquo;maybe&rdquo; (&rArr; check at runtime).

&nbsp;

Refinement extensions exist for [C](http://goto.ucsd.edu/csolve/), [ML](https://www.cs.cmu.edu/~fp/papers/pldi91.pdf), [Haskell](http://goto.ucsd.edu/~rjhala/liquid/haskell/blog/about/), [C#](http://research.microsoft.com/en-us/projects/specsharp/), [F#](http://research.microsoft.com/en-us/projects/f7/)

[miTLS](http://www.mitls.org/wsgi/home) ([live demo](https://www.mitls.org:2443/wsgi/home)) is a verified SSL/TLS stack.

They found a [protocol bug](https://www.secure-resumption.com/) too!

# (Co-)inductive constructions

A different approach to dependent types.

*Calculus of constructions* + [*generalized algebraic data types*](http://downloads.haskell.org/~ghc/latest/docs/html/users_guide/data-type-extensions.html#gadt)

&nbsp;

Programs *are proofs* (Curry-Howard correspondence)

Programs are correct *by construction*

# Defining an inductive type

Each `enum` constructor specifies its type.

```rust
enum Nat {
    Zero: Nat,
    Succ(Nat): Nat,
}

enum Vec(T: type, len: Nat) {
    Nil:
        Vec(T, Nat::Zero),

    Cons(T, Vec(T, len)):
        Vec(T, Nat::Succ(len)),
}
```

# Inductive data can refine, too

```rust
enum Equal(T: type, a: T, b: T) {
    Refl: Equal(T, a, a),
}

struct Refine(T: type, p: T -> bool) {
    value: T,
    proof: Equal(bool, true, p(value)),
}

fn range(lo: isize, hi: isize) -> type {
    Refine(isize, |x| lo <= x && x < hi)
}

enum Tree ... // as before
```

# Using inductive data

Hand-written proofs based on pattern matching.

Help from editor integration or automated &ldquo;proof tactics&rdquo;.

&nbsp;

Coq supports compiling to Haskell, OCaml, Scheme...

How about Rust? [Work is underway.](https://github.com/rust-lang/rfcs/issues/667)

# Dependent types for Rust?

Sounds like a fantasy...

So did &ldquo;concurrent memory safety for C++&rdquo;.

What will Rust and its offspring look like in another decade?

# What to read next

Pierce et al. [*Software Foundations*](http://www.cis.upenn.edu/~bcpierce/sf/current/index.html).<br/>Free online w/ machine-guided exercises!

Norell & Chapman. &ldquo;[Dependently Typed Programming in Agda](http://www.cse.chalmers.se/~ulfn/darcs/AFP08/LectureNotes/AgdaIntro.pdf)&rdquo;

The [Idris documentation](http://www.idris-lang.org/documentation/).

Pierce. (2002). [*Types and Programming Languages*](https://www.cis.upenn.edu/~bcpierce/tapl/). MIT Press.

# Other recommended reading

<div style="font-size: 60%;">

<p>Gronski, J., Knowles, K., Tomb, A., Freund, S. N., & Flanagan, C. (2006). <a href="http://kennknowles.com/research/gronski-knowles-tomb-flanagan-freund.tr.06.sage.pdf">Sage: Hybrid checking for flexible specifications</a>. <i>Scheme and Functional Programming Workshop</i> (pp. 93-104).</p>

<p>Harper, R. (2012). <i>Practical Foundations for Programming Languages</i> (<a href="http://www.cs.cmu.edu/~rwh/plbook/book.pdf">draft online</a>). Cambridge University Press.</p>

<p>Löh, A., McBride, C., & Swierstra, W. (2010). <a href="http://www.andres-loeh.de/LambdaPi/">A tutorial implementation of a dependently typed lambda calculus</a>. <i>Fundamenta informaticae</i>, 102(2), pp. 177-207.</p>

<p>Ou, X., Tan, G., Mandelbaum, Y., & Walker, D. (2004). <a href="https://www.cs.princeton.edu/~dpw/papers/DTDT-tr.pdf">Dynamic typing with dependent types</a>. <i>Exploring New Frontiers of Theoretical Informatics</i> (pp. 437-450). Springer US.</p>

<p>Pierce, B. (Ed.) (2005). <a href="https://www.cis.upenn.edu/~bcpierce/attapl/"><i>Advanced Topics in Types and Programming Languages</i></a>. MIT Press.</p>

<p>Rondon, P. M., Kawaguci, M., & Jhala, R. (2008). <a href="http://goto.ucsd.edu/~rjhala/liquid/liquid_types_techrep.pdf">Liquid types</a>. <i>ACM SIGPLAN Notices</i> 43(6), pp. 159-169.</p>

<p>Wadler, P., & Findler, R. B. (2009). <a href="https://www.era.lib.ed.ac.uk/bitstream/handle/1842/3685/Well-typed%20programs%20can%20t%20be%20blamed.pdf?sequence=2">Well-typed programs can’t be blamed</a>. <i>Programming Languages and Systems</i> (pp. 1-16). Springer Berlin Heidelberg.</p>

</div>
