% Rust macros in html5ever

Keegan McAllister

November 6, 2014

<div style="padding-top: 40px; font-size: 60%">
<p>Navigate with ← and → keys, or <a href="#" id="view-all">view all slides</a>.</p>
<p>Available at <a href="http://kmcallister.github.io/talks/rust/2014-rust-macros/slides.html"><code>kmcallister.github.io</code></a></p>
</div>

# The Servo project

Servo is an experimental browser engine from Mozilla Research

Developed by a dozen Mozilla employees + hundreds of others

Layout code is all-new and written in Rust

* 2013-09: passed Acid1 test
* 2014-01: parallel layout (!!!)
* 2014-05: passed Acid2 test
* 2014-08: vertical writing (preliminary)
* 2014-10: incremental layout 

# Acid1 cake

<div class="image"><img src="acid1.jpeg" /></div>

# Acid2 cake

<div class="image"><img src="acid2.jpeg" /></div>

# Bootstrapping

C libs replaced in Rust:

* 2013-10: CSS parsing
* 2014-07: string interning
* 2014-10: HTML parsing
* 2014-11: OpenGL windowing

Faster, cleaner, more safe, more correct

Future: JS engine, rasterizer?

# HTML parsing

What is the HTML syntax? Depends who you ask!

* W3C spec: <b>8 pages</b>
* WHATWG spec: <b>114 pages</b>

Which one is relevant for real browsers and content?

# TURN DOWN FOR WHATWG

<div class="image"><img src="sink.png" style="width: 60%" /></div>

# Parsing rules

<blockquote>
<dl class="switch">
<dt>A start tag whose tag name is "nobr"</dt>
<dd>
<p><em>Reconstruct the active formatting elements</em>, if any.</p>
<p>If the <em>stack of open elements</em> <em>has a <code>nobr</code> element in scope</em>, then this is a <em>parse error</em>; run the <em>adoption agency algorithm</em> for the tag name "nobr", then once again <em>reconstruct the active formatting elements</em>, if any.</p>
<p><em>Insert an HTML element</em> for the token. <em>Push onto the list of active formatting elements</em> that element.</p>
</dd>
</dl>
</blockquote>

# Parsing rules

<blockquote>
<p>When the steps below require the UA to <dfn>generate implied end tags</dfn>, then, while the <em>current node</em> is a <code>dd</code> element, a <code>dt</code> element, an <code>li</code> element, …</p>
<p>When the steps below require the UA to <dfn>generate all implied end tags thoroughly</dfn>, then, while the <em>current node</em> is a <code>caption</code> element, a <code>colgroup</code> element, an <code>dd</code> element, …</p>
</blockquote>

# whyyyyyy

The upside: Any crap HTML (even 1996 GeoCities) will parse the same in every modern browser

<div class="image"><img src="under-construction.png" /></div>

<p><code>&lt;kmc&gt; should I be scared when the WHATWG spec says "for historical reasons"? because I feel like that phrase already applies to the entire document</code></p>
<p><code>&lt;Ms2ger&gt; Correct</code></p>
<p><code>&lt;Ms2ger&gt; That just means "for historical reasons we dislike particularly"</code></p>

# html5ever

html5ever is Servo's new HTML parser, written mostly by me over the course of about 7 months

We now have 8 contributors and <i>several</i> users!

Fast, safe, generic, native UTF-8

Rust and C APIs available

# Macros in html5ever

Factor the problem into:

* Small amount of difficult macro code
* Large amount of mindlessly transcribed rules

Bonus: code looks like the spec!

# Tokenizer rule

<blockquote>
<h5>12.2.4.1 <dfn>Data state</dfn></h5>
<p>Consume the <em>next input character</em>:</p>
<dl class="switch"><dt>U+0026 AMPERSAND (&amp;)</dt><dd>Switch to the <em>character reference in data state</em>.</dd><dt>U+003C LESS-THAN SIGN (&lt;)</dt><dd>Switch to the <em>tag open state</em>.</dd><dt>U+0000 NULL</dt><dd><em>Parse error</em>. Emit the <em>current input character</em> as a character
   token.</dd><dt>EOF</dt><dd>Emit an end-of-file token.</dd><dt>Anything else</dt><dd>Emit the <em>current input character</em> as a character token.</dd></dl>
</blockquote>

# Tokenizer code

```rust
match self.state {
    states::Data => loop { match get_char!(self) {
        '&'  => go!(self: consume_char_ref),
        '<'  => go!(self: to TagOpen),
        '\0' => go!(self: error; emit '\0'),
        c    => go!(self: emit c),
    }},
```

<p>In Hubbub this is about <b>150 lines of C</b>.</p>

<p>In html5lib it's <b>20 lines of Python</b>.</p>

# Incremental parsing

```rust
// Feed more input
fn feed(&mut self, input: String);

// Get next character, if available
fn get_char(&mut self) -> Option<char>;

// true => made progress
fn step(&mut self) -> bool;

fn run(&mut self) {
    while self.step() { }
}
```

# `get_char!`

```rust
macro_rules! unwrap_or_return (
    ($opt:expr, $retval:expr) => (
        match $opt {
            None => return $retval,
            Some(x) => x,
        }
    )
)

macro_rules! get_char (
    ($me:expr) => (
        unwrap_or_return!($me.get_char(), false)
    )
)
```

# Tokenizer actions

```rust
macro_rules! shorthand (

    ($me:expr: emit $c:expr)
        => ( $me.emit_char($c); );

    // 22 more of these
)
```

Allows for compact sequencing:

```rust
go!(self: error; create_doctype; force_quirks;
          emit_doctype; to Data)
```

`go!` is used over 200 times.

# Sequencing

A pattern like `$($cmd:tt)* ; $($rest:tt)*` is ambiguous :(

```rust
macro_rules! go (
  ($me:expr: $a:tt                 ; $($rest:tt)* )
    => ({ shorthand!($me: $a);       go!($me: $($rest)*); });

  ($me:expr: $a:tt $b:tt           ; $($rest:tt)* )
    => ({ shorthand!($me: $a $b);    go!($me: $($rest)*); });

  ($me:expr: $a:tt $b:tt $c:tt     ; $($rest:tt)* )
    => ({ shorthand!($me: $a $b $c); go!($me: $($rest)*); });
```

# Sequencing (continued)

```rust
  // Can only come at the end
  ($me:expr: to $s:ident)
    => ({ $me.state = states::$s; return true; });

  // Base cases
  ($me:expr: $($cmd:tt)+ )
    => ( shorthand!($me: $($cmd)+); );

  ($me:expr: ) => (());
)
```

# Procedural macros

We're already stretching the limits of `macro_rules!` and we haven't touched
tree construction…

**Procedural macros** run arbitrary Rust code at compile time,  
using `rustc`'s plugin infrastructure

See [`doc.rust-lang.org/guide-plugin.html`](http://doc.rust-lang.org/guide-plugin.html)

# Named characters

`&lt;` parses as "&lt;"

`&ContourIntegral;` parses as "&ContourIntegral;"

WHATWG publishes about 2,000 of these as JSON

```rust
pub static NAMED_ENTITIES: PhfMap<&'static str, [u32, ..2]>
    = named_entities!("data/entities.json");
```

# The `named_entities!` macro

```rust
let map: HashMap<String, [u32, ..2]> = ...;

let toks: Vec<_> = map.into_iter().flat_map(
    |(k, [c0, c1])| {
        let k = k.as_slice();
        (quote_tokens!(&mut *cx,
            $k => [$c0, $c1],
        )).into_iter()
    }
).collect();

MacExpr::new(quote_expr!(&mut *cx,
    phf_map!($toks)
))
```

# Perfect hashing

We use another procedural macro, from sfackler's [`rust-phf`](https://github.com/sfackler/rust-phf) library,
to generate a perfect hash table at compile time.

```rust
phf_map!(k => v,
         k => v,
         ...)
```

# Tree builder actions

Tree builder has its own rules, less regular in form than the tokenizer.

Instead of `match` + `go!`, we'll need a procedural macro.

# `match_token!`

```rust
match mode {
    InBody => match_token!(token { 
        tag @ </a> </b> </big> </code> </em> </font>
              </i> </nobr> </s> </small> </strike>
              </strong> </tt> </u> => {
            self.adoption_agency(tag.name);
            Done
        }

        tag @ <h1> <h2> <h3> <h4> <h5> <h6> => {
            self.close_p_element_in_button_scope();
            if self.current_node_in(heading_tag) {
                // ...
```

# Custom syntax trees

```rust
struct Tag {
    kind: TagKind,
    name: Option<TagName>,  // None for wild
}

/// Left-hand side of a pattern-match arm.
enum LHS {
    Pat(P<ast::Pat>),
    Tags(Vec<Spanned<Tag>>),
}
```

# Source code spans

In `syntax::codemap` you will find

```rust
pub struct Span {
    pub lo: BytePos,
    pub hi: BytePos,

    /// Macro expansion context
    pub expn_info: Option<P<ExpnInfo>>
}

pub struct Spanned<T> {
    pub node: T,
    pub span: Span,
}
```

# Tracking spans

```rust
use syntax::codemap::{Span, Spanned, spanned};
use syntax::parse::parser::Parser;

fn parse_spanned_ident(parser: &mut Parser)
    -> Spanned<Ident>
{
    let lo = parser.span.lo;
    let ident = parser.parse_ident();
    let hi = parser.last_span.hi;
    spanned(lo, hi, ident)
}
```

# Throwing compiler errors

```rust
macro_rules! bail (
    ($cx:expr, $span:expr, $msg:expr) => ({
        $cx.span_err($span, $msg);
        return ::syntax::ext::base::DummyResult::any($span);
    })
)

macro_rules! bail_if (
    ($e:expr, $cx:expr, $span:expr, $msg:expr) => (
        if $e { bail!($cx, $span, $msg) }
    )
)
```

# Validating macro input

```rust
match (lhs.node, rhs.node) {
    (Pat(pat), Expr(expr)) => {
        bail_if!(!wildcards.is_empty(), cx, lhs.span,
            "ordinary patterns may not appear after \
             wildcard tags");
```

Do this to guarantee the semantics of in-order matching

<pre><code>src/tree_builder/rules.rs:100:17: 100:48
  <span style="color: red">error:</span> ordinary patterns may not appear after wildcard tags
src/tree_builder/rules.rs:100
  CharacterTokens(NotSplit, text) => SplitWhitespace(text),
  <span style="color: red">^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~</span>
<b><span style="color: red">error:</span> aborting due to previous error</b>
</code></pre>

# My favorite rule in the spec

<blockquote style="margin-top: 240px;">
<dl class="switch">
<dt>An end tag whose tag name is "sarcasm"</dt>
<dd>Take a deep breath, then act as described in the "any other end tag" entry below.</dd>
</dl>
</blockquote>
