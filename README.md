# frank

A small parser to process single-line, whitespace-delimited input using a
grammar.

## Examples

```elixir
iex> Frank.parse "Parse me!", ~w(Parse me!)
{:ok, [root: []]}

iex> Frank.parse "Parse me!", ~w(Parse me!)a
{:ok, [root: [:Parse, :me!]]}

iex> Frank.parse "Parse me!", [~r/Parse/, ~r/me!/]
{:ok, [root: ["Parse", "me!"]]}

iex> Frank.parse "Parse me!", [~r/arse/, ~r/me!/]
{:ok, [root: ["Parse", "me!"]]}

iex> Frank.parse "Parse me!", [~r/^arse/, ~r/me!/]
{:error, :nomatch, "Parse me!"}

iex> import Frank
iex> Frank.parse "192.0.2.253", [ip("192.0.2.0/24")]
{:ok, [root: [%NetAddr.IPv4{address: <<192, 0, 2, 253>>, length: 32}]]}

iex> import Frank
iex> Frank.parse "c0ff:33c0:ff33::/48", [ip("::/0")]
{:ok, [root: [%NetAddr.IPv6{address: <<0xc0ff33c0ff33::48, 0::80>>, length: 48}]]}

iex> Frank.parse "Transform me!", [~r/transform/i, {"me!", "you!"}]
{:ok, [root: ["Transform", "you!"]]}

iex> Frank.parse "55", [1..100]
{:ok, [root: [55]]}

iex> import Frank
iex> parse "I am a duck", ~w(I am a) ++ one_of ~w(swan goose duck)a
{:ok, [root: [:duck]]}

iex> import Frank
iex> parse "This is a poodle", [~w(This is a), maybe("french"), :poodle]
{:ok, [root: [:poodle]]}

iex> import Frank
iex> parse "This is a french poodle", [~w(This is a), maybe("french"), :poodle]
{:ok, [root: [:poodle]]}

iex> import Frank
iex> adjective = one_of ~w(suli lili)a
iex> parse "mi moku suli e telo nasa", [~w(mi moku), maybe(adjective), ~w(e telo nasa)]
{:ok, [root: [:suli]]}

iex> import Frank
iex> word = ~r/^telo|nasa|pona$/
iex> parse "telo nasa li pona", [{:subject, [word, maybe(word)]}, "li", {:predicate, [word]}]
{:ok, [root: [subject: ["telo", "nasa"], predicate: ["pona"]]]}
```

## Installation

Add `frank` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:frank, git: "https://github.com/jonnystorm/frank.git"}]
end
```

