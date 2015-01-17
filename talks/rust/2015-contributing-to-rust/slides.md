% Getting started contributing to Rust

SF Bay Area Rust Meetup

January 17, 2015

<div style="padding-top: 40px; font-size: 60%">
<p>Navigate with ← and → keys, or <a href="#" id="view-all">view all slides</a>.</p>
<p>Available at <a href="http://kmcallister.github.io/talks/rust/2015-contributing-to-rust/slides.html"><code>kmcallister.github.io</code></a></p>
</div>

# Hello, world!

```rust
fn main() {
    println!("Hello, world!");
}
```

Let's trace this program's exciting journey through the compiler.

Based on `rustc -Z time-passes`

Numerous details omitted.

# Hello compiler!

Execution starts in `librustc_driver/lib.rs`

Overall compilation pipeline in `librustc_driver/driver.rs`

Parse command-line options in `librustc/session/config.rs`

Build a `Session` with overall compiler state

# Parsing

UTF-8 string &rarr; tokens &rarr; abstract syntax tree (AST)

Parser is 6,000+ lines hand-written Rust code in libsyntax

Macro invocs are parsed as e.g. expressions or items, but the body is parsed
only to a token tree.

Record `Span`s for AST nodes: byte ranges in the original source

# `rustc --pretty normal`

```rust
fn main() { println!("Hello, world!"); }
```

# Syntax expansion

* Strip items based on `cfg(...)`
* Load compiler plugins and exported macros
* Expand macros / syntax extensions
* Strip based on `cfg(...)` *again*
* Inject imports for std and `prelude::*`

# `rustc --pretty expanded`

```rust
#![no_std]
#[macro_use]
extern crate "std" as std;
#[prelude_import]
use std::prelude::v1::*;
fn main() {
    ::std::io::stdio::println_args(
        ::std::fmt::Arguments::new({
            #[inline]
            #[allow(dead_code)]
            static __STATIC_FMTSTR: &'static [&'static str]
                   = &["Hello, world!"];
            __STATIC_FMTSTR
        }, &match () { () => [], }));
}
```

# What? AST is evolving!

* Freeze the shape of the tree
* Assign each node a unique `NodeId`
* Build an index by `NodeId` of AST nodes and their parents

See `libsyntax/ast_map`

Further analysis (types etc.) mostly creates side tables indexed by `NodeId`.

# Name resolution

* Load definitions from external libs
* Find the (local or external) def'n for each local name
* Look for special stuff: lang items, plugin registrar, `main`

`librustc_resolve`

# Type checking

* Variance inference
* Coherence checking
* Type inference & checking

See `librustc_typeck`

# `rustc --pretty typed`

```rust
#![no_std] #[macro_use] extern crate "std" as std;
#[prelude_import] use std::prelude::v1::*;
fn main() {(
  (::std::io::stdio::println_args as fn(core::fmt::Arguments<'_>))(
    ((::std::fmt::Arguments::new as fn(&[&str], &[core::fmt::Argument<'_>]) -> core::fmt::Arguments<'_>)(
      ({ #[inline] #[allow(dead_code)]
        static __STATIC_FMTSTR: &'static [&'static str]
          = &([("Hello, world!" as &'static str)] as [&'static str; 1])
            as &'static [&'static str; 1];
        (__STATIC_FMTSTR as &'static [&'static str])
      } as &[&str]), (
        &(match (() as ()) {
          () => ([] as [core::fmt::Argument<'_>; 0]),
        } as [core::fmt::Argument<'_>; 0]) as &[core::fmt::Argument<'_>; 0])
    ) as core::fmt::Arguments<'_>)
  ) as ()
); }
```

# Borrow checking

See `librustc_borrowck/borrowck/doc.rs` for an overview.

(Some other components also have `doc.rs`!)

# Misc checking

check static items, const marking, const checking, privacy checking, intrinsic
checking, effect checking, match checking, liveness checking, rvalue checking,
reachability checking, death checking

# Lint checking

Lint system defined in `librustc/lint`

* Interface in `mod.rs`
* Infrastructure and traversal in `context.rs`
* Built-in lints *mostly* in `builtin.rs`
* Plugins use the same interface

Some "hardwired" lints are recorded earlier in the pipeline and emitted here

Some extra special lints run after this point

Not all `warning` messages are lints!

# Translating to LLVM

Everything up to this point is a small fraction of compile time.

Next big step: translate to LLVM code

Happens directly from AST, with heavy use of the side tables computed earlier.

`librustc_trans/trans`

# The LLVM project

A language-independent optimizing compiler backend

A million lines of code developed over 12+ years

Other users: clang, Swift, Rubinius, GHC, Webkit, MesaGL

LLVM is roughly the same language on every platform

Individual programs are *not* portable due to struct layouts, etc.

# The LLVM language

Sort of a hybrid of C and assembly, but with an infinite number of "registers"

These local vars are immutable: static single assignment (SSA)

When in doubt: Emit code similar to clang's

# `rustc --emit llvm-ir`

```text
define internal void @_ZN4main20hd39b92e2a88a8c7deaaE()
    unnamed_addr #0 {
entry-block:
  %addr_of = alloca [0 x %"struct.core::fmt::Argument[#2]"], align 8
  %0 = alloca %"struct.core::fmt::Arguments[#2]", align 8
  %1 = bitcast %"struct.core::fmt::Arguments[#2]"* %0 to i8*
  call void @llvm.lifetime.start(i64 48, i8* %1)
  %2 = bitcast [0 x %"struct.core::fmt::Argument[#2]"]* %addr_of to i8*
  call void @llvm.lifetime.start(i64 0, i8* %2)
  %3 = getelementptr inbounds [0 x %"struct.core::fmt::Argument[#2]"]* %addr_of, i64 0, i64 0
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %1, i8* bitcast ({ %str_slice*, i64 }* @_ZN4main15__STATIC_FMTSTR20h96ab25eba9ca53ccqaaE to i8*), i64 16, i32 8, i1 false) #3, !alias.scope !0, !noalias !4
```

# LLVM optimization

Lots of time spent here!

We rely on LLVM's fantastic optimizations to tear apart Rust's abstractions, in particular:

* Scalar replacement of aggregates (SROA): analyze compound data structures as collections of local variables
* Inlining to enable further optimizations

Very powerful, e.g. turning iterator chains into flat loops

# LLVM &rarr; native code

Also fairly time-consuming

* Register allocation
* Instruction selection
* Instruction scheduling

# `rustc --emit asm`

```text
_ZN4main20hd39b92e2a88a8c7deaaE:
	.cfi_startproc
	cmpq	%fs:112, %rsp
	ja	.LBB0_2
	movabsq	$56, %r10
	movabsq	$0, %r11
	callq	__morestack
	retq
.LBB0_2:
	subq	$56, %rsp
.Ltmp0:
	.cfi_def_cfa_offset 64
	movups	_ZN4main15__STATIC_FMTSTR20h96ab25eba9ca53ccqaaE(%rip), %xmm0
	movaps	%xmm0, (%rsp)
	movq	$0, 16(%rsp)
	leaq	48(%rsp), %rax
	movq	%rax, 32(%rsp)
	movq	$0, 40(%rsp)
	leaq	(%rsp), %rdi
	callq	_ZN2io5stdio12println_args20h0f21e194a55552ebNTgE@PLT
	addq	$56, %rsp
	retq
```

# Assembly and linking

Use either the platform assembler or LLVM's built-in one

Force platform assembler with `rustc -C no-integrated-as`

Use the platform linker

Optional link-time optimization by LLVM (`-C lto`)

# `objdump -d hello`

```text
56e0 <_ZN4main20hd39b92e2a88a8c7deaaE>:
 56e0:  64 48 3b 24 25 70 00  cmp    %fs:0x70,%rsp
 56e7:  00 00 
 56e9:  77 1a                 ja     5705 <_ZN4main20hd39b92e2a88a8c7deaaE+0x25>
 56eb:  49 ba 38 00 00 00 00  movabs $0x38,%r10
 56f2:  00 00 00 
 56f5:  49 bb 00 00 00 00 00  movabs $0x0,%r11
 56fc:  00 00 00 
 56ff:  e8 54 00 00 00        callq  5758 <__morestack>
 5704:  c3                    retq   
 5705:  48 83 ec 38           sub    $0x38,%rsp
 5709:  0f 10 05 80 61 25 00  movups 0x256180(%rip),%xmm0
  # 25b890 <_ZN4main15__STATIC_FMTSTR20h96ab25eba9ca53ccqaaE>
 5710:  0f 29 04 24           movaps %xmm0,(%rsp)
 5714:  48 c7 44 24 10 00 00  movq   $0x0,0x10(%rsp)
 571b:  00 00 
 571d:  48 8d 44 24 30        lea    0x30(%rsp),%rax
 5722:  48 89 44 24 20        mov    %rax,0x20(%rsp)
 5727:  48 c7 44 24 28 00 00  movq   $0x0,0x28(%rsp)
 572e:  00 00 
 5730:  48 8d 3c 24           lea    (%rsp),%rdi
 5734:  e8 27 47 00 00        callq  9e60 <_ZN2io5stdio12println_args20h0f21e194a55552ebNTgE>
 5739:  48 83 c4 38           add    $0x38,%rsp
 573d:  c3                    retq   
```

# Hello, world!

```text
$ ./hello 
Hello, world!
```

# The Rust test suite

Move fast and *don't* break things

(At least, not by accident...)

Test effort pays off immensely with years of rapid change

# Compiler tests

Found under `src/test`:

* compile fail, run fail, run pass
* pretty print and re-parse
* benchmarks
* check debug info in GDB or LLDB
* code size comparison w/ C++
* custom Makefile-based test

Mostly implemented by `src/compiletest`

`src/test/auxiliary` has extra crates for multi-crate tests

# Library tests

Good old `#[test]` and `assert!`

Same for compiler's own unit tests

libcore has an external libcoretest (see commit `1ed646e`)

`src/libsyntax/test.rs` generates the test harness and links libtest

# Documentation tests

We test code blocks in documentation!

Skip with <code>&#96;&#96;&#96;ignore</code>, compile-only with
<code>&#96;&#96;&#96;no_run</code>

Lines starting with `#` are compiled but not shown

Harness detects whether to add `fn main() {`

Hence this idiom:

```text
# fn main() { }
```

# The Rust build system

4,000+ lines of Makefiles

Downloads stage0 "snapshot"

Uses it to build stage1 rustc + libs, uses those to build stage2

Also builds own copy of LLVM, with a few local patches

# Build recipes

Run `make tips` to learn loads of build system tricks

```text
make VERBOSE=1
make docs
make check-stage1-rpass TESTNAME=my-shiny-new-test
make check-stage1-std NO_REBUILD=1
```

`make -j` will do a parallel build, to the extent possible

Tests within a suite automatically run in parallel

# Contributing

Guidelines in-repo as [`CONTRIBUTING.md`](https://github.com/rust-lang/rust/blob/master/CONTRIBUTING.md)

Rebase against `master`, submit a pull request to `rust-lang/rust`

["Substantial"
changes](https://github.com/rust-lang/rfcs/#when-you-need-to-follow-this-process)
go through the [RFC process](https://github.com/rust-lang/rfcs)

Always include tests!

Style: 100 char lines, 4-space indent

Be consistent with existing code, but modernize when you can

# Resources

[Notes for developers](https://github.com/rust-lang/rust/wiki/Notes) at
`github.com/rust-lang/rust/wiki/Notes`

Please review the [code of conduct and moderation policy](https://github.com/rust-lang/rust/wiki/Note-development-policy#conduct)

`#rust-internals` on `irc.mozilla.org`

# Finding things to work on

Rust's [GitHub issues](https://github.com/rust-lang/rust/issues) have tags

E-easy means a good beginner bug. Don't feel bad if it turns out to be hard, though!

A-docs, A-rustdoc have lots of work ready to go

A-diagnostics: compiler errors always need work

Add stuff to `rustc --explain`

Following up on old or unlabeled bugs is also very useful

# Resources for this event

`#rust-workshop` on `irc.mozilla.org`

Etherpad at [`http://is.gd/ruXbt1`](http://is.gd/ruXbt1)

Add what you're working on

Teamwork is encouraged!
