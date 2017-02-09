defmodule FrankTest do
  use ExUnit.Case
  doctest Frank

  import Frank

  test "parses with simple, realistic grammar" do
    port_number = 1..65535
    port_keyword =
      one_of [ {:ftp,         21},
               {~r/http|www/, 80},
               {:https,      443},
               {:ssh,         22},
               {:telnet,      23},
               {:tftp,        69},
             ]

    port = one_of [port_number, port_keyword]
    port_match = one_of [ [one_of(~w(eq gt lt neq)a), port],
                          [:range, port, port],
                        ]

         source = {     :source, ["source",      port_match]}
    destination = {:destination, ["destination", port_match]}

    grammar =
      {:service_def,
        ["service", one_of([ [source, maybe(destination)],
                             [destination],
                           ])]}

    string = "service source gt 1023 destination range 22 www"

    assert parse(string, grammar) ==
      {:ok, [root: [service_def: [ source: [:gt, 1023],
                                   destination: [:range, 22, 80]
                                 ]]]}
  end

  test "parses another realistic grammar" do
    spec = one_of [ [net_obj_def: [fqdn: ["fqdn", maybe(:v4), ~r/^.*$/]]],
                    [static_obj_nat: ["nat", maybe(~r/^\(.*,.*\)$/), "static", ip("0/0")]],
                  ]

    assert parse("nat (dmz,outside) static 192.0.2.1", spec)
      == {:ok, [root: [static_obj_nat: ["(dmz,outside)", NetAddr.ip("192.0.2.1")]]]}
  end
end
