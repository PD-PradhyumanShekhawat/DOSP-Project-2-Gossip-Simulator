-module(gossip_tests).

-include_lib("eunit/include/eunit.hrl").

invalid_node_count_test() ->
    ?assertError(
        {invalid_num_nodes, positive_integer_required},
        coordinator:run(0, full, gossip)
    ).

invalid_topology_test() ->
    ?assertError(
        {invalid_topology, invalid},
        coordinator:run(4, invalid, gossip)
    ).

invalid_algorithm_test() ->
    ?assertError(
        {invalid_algorithm, invalid},
        coordinator:run(4, full, invalid)
    ).