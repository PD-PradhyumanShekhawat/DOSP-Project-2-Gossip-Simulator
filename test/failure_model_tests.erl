-module(failure_model_tests).

-include_lib("eunit/include/eunit.hrl").

no_failures_preserve_full_graph_test() ->
    Original = topology:build(4, full),
    {Filtered, Failed} = failure_model:apply(Original, 0.0),
    ?assertEqual(0, Failed),
    ?assertEqual(Original, Filtered),
    ?assert(failure_model:is_connected(Filtered)).

all_failures_remove_full_graph_edges_test() ->
    Original = topology:build(4, full),
    {Filtered, Failed} = failure_model:apply(Original, 1.0),
    ?assertEqual(6, Failed),
    ?assertEqual(#{1 => [], 2 => [], 3 => [], 4 => []}, Filtered),
    ?assertNot(failure_model:is_connected(Filtered)).

failed_edges_are_symmetric_test() ->
    Original = topology:build(9, '2D'),
    {Filtered, _Failed} = failure_model:apply(Original, 0.4),
    maps:foreach(
        fun(Id, Neighbors) ->
            lists:foreach(
                fun(Neighbor) ->
                    ?assert(lists:member(Id, maps:get(Neighbor, Filtered)))
                end,
                Neighbors
            )
        end,
        Filtered
    ).

single_node_is_connected_test() ->
    ?assert(failure_model:is_connected(#{1 => []})).
