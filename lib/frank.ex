# Copyright © 2017 Jonathan Storm <jds@idio.link>
# This work is free. You can redistribute it and/or modify it under the
# terms of the Do What The Fuck You Want To Public License, Version 2,
# as published by Sam Hocevar. See the COPYING.WTFPL file for more
# details.

defmodule Frank do
  require Logger

  defp reverse({op, list})
      when is_list(list),   do: {op, Enum.reverse(list)}
  defp reverse(any),        do: any

  defp nest(token1, token2) do
    case {token1, token2} do
      {   [], {name,  nil}}                    -> {name, nil}
      {token, {name,  nil}} when is_list token -> {name, token}
      {token, {name,  nil}}                    -> {name, [token]}
      {token,         list} when is_list(token)
                             and is_list(list) -> token ++ list
      {token, {name, list}} when is_list(token)
                             and is_list(list) -> {name, token ++ list}
      {token, {name, list}} when is_list list  -> {name, [token|list]}
      {token,         list} when is_list list  -> [token|list]
    end
  end

  defp unhd(head, tail), do: [head|tail]

  defp accrete([token1, token2|rest]) do
    :ok = Logger.debug("Accrete token stack: [#{inspect token1}, #{inspect token2} | #{inspect rest}")

    token1
      |> reverse
      |> nest(token2)
      |> unhd(rest)
  end

  defp accrete(term), do: term

  # Terminating condition: success
  defp _parse([[]], [], :match, [{:root, _} = root]),
    do: {:ok, [reverse(root)]}

  # Accrete dangling branches into root
  defp _parse([[]], [], _, acc),
    do: _parse([[]], [], :match, accrete(acc))

  # Terminating condition: failure
  defp _parse([input|_], [], _, _) do
    {:error, :nomatch, Enum.join(input, " ")}
  end

  # Replace bare list with {:and, list}
  defp _parse(input, [list|stack], last_result, acc) when is_list(list),
    do: _parse(input, [{:and, list}|stack], last_result, acc)

  # When patterns for this branch are exhausted
  defp _parse(input, [{op, []}|stack], last_result, acc) when is_atom(op) do
    case {op, last_result} do
      {   _,      nil} -> _parse(   input,  stack, :nomatch,       acc)   # start/fail
      {:and, :nomatch} -> _parse(   input,  stack, :nomatch,    tl(acc))  # term/fail
      { :or, :nomatch} -> _parse(tl(input), stack, :nomatch,    tl(acc))  # term/fail
      {:and,   :match} -> _parse(   input,  stack, :match, accrete(acc))  # term/succeed
      { :or,   :match} ->                                                 # term/succeed
        _parse(List.delete_at(input, 1),    stack, :match, accrete(acc))
    end
  end

  # While patterns for this branch remain
  defp _parse(input, [{op, [h|t]}|stack], last_result, acc) when is_atom(op) do
    case {op, last_result} do
      {:and,   :match} -> _parse(input, [h, {op, t}|stack], nil, [[]|accrete(acc)])  # continue
      {:and,      nil} -> _parse(input, [h, {op, t}|stack], nil,         [[]|acc])   # start
      {:and, :nomatch} -> _parse(input,             stack, :nomatch,      tl(acc))   # abort/fail
      { :or, :nomatch} ->                                                            # continue
        input = tl input

        _parse([hd(input)|input], [h, {op, t}|stack], nil,      acc)

      {:or, nil} ->     # start
        _parse([hd(input)|input], [h, {op, t}|stack], nil,  [[]|acc])

      {:or, :match} ->  # abort/succeed
        _parse(List.delete_at(input, 1), stack, :match, accrete(acc))

      {name, _} ->      # capture matching input
        _parse(input, [{:and, [h|t]}|stack], nil, [{name, nil}|acc])
    end
  end

  # nil positively matches nothing, consuming no input
  defp _parse(input, [nil|stack], nil, acc),
    do: _parse(input, stack, :match, tl(acc))

  # Discard current pattern and return :nomatch when there is nothing to match
  defp _parse([[]|_] = input, [_|stack], nil, acc),
    do: _parse(input, stack, :nomatch, acc)

  # Match next word in input
  defp _parse([[h|t]|rest], [top|stack], nil, acc) do
    if value = match(h, top) do
      _parse([   t |rest], stack, :match, accrete([value|acc]))
    else
      _parse([[h|t]|rest], stack, :nomatch,              acc)
    end
  end

  @doc """
  Parse a single-line, space-delimited input string given a grammar with which
  to parse it.

  ## Examples

      iex> Frank.parse "Parse me!", ~w(Parse me!)
      {:ok, [root: nil]}

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

      iex> import Frank
      iex> word = ~r/^telo|nasa|pona$/
      iex> parse "telo nasa li ", [{:subject, [word, maybe(word)]}, "li", {:predicate, maybe(word)}]
      {:ok, [root: [subject: ["telo", "nasa"], predicate: nil]]}
  """
  def parse(input, grammar),
    do: _parse([String.split(input)], [grammar], nil, [{:root, nil}])

  defp match_ip(netaddr, string) do
    case NetAddr.ip(string) do
      {:error, _} ->
        nil

      ip ->
        NetAddr.contains?(netaddr, ip) && ip || nil
    end
  end

  defp match_range(range, string) do
    case Integer.parse(string) do
      {int, ""} ->
        (int in range) && int || nil

      _ ->
        nil
    end
  end

  defp match(string, pattern) when is_binary(string) do
    case pattern do
      ^string          -> []
      %NetAddr.IPv4{}  ->    match_ip(pattern, string)
      %NetAddr.IPv6{}  ->    match_ip(pattern, string)
      %Range{}         -> match_range(pattern, string)
      %Regex{}         -> string =~ pattern  && string || nil
      {pat, val}       -> match(string, pat) &&    val || nil
      a when is_atom a -> string == "#{a}"   &&      a || nil
      _                -> nil
    end
  end

  def ip(string) when is_binary(string), do: NetAddr.ip(string)

  def maybe(term), do: [{:or, [term, nil]}]

  def one_of(list) when is_list(list), do: [{:or, list}]
end

