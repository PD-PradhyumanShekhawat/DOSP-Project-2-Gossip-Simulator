-module(topology_tests).

-include_lib("eunit/include/eunit.hrl").

full_network_test() ->
    T = topology:build(4, full),
    ?assertEqual([2, 3, 4], maps:get(1, T)),
    ?assertEqual([1, 3, 4], maps:get(2, T)),
    ?assertEqual([1, 2, 3], maps:get(4, T)).

line_network_test() ->
    T = topology:build(5, line),
    ?assertEqual([2], maps:get(1, T)),
    ?assertEqual([1, 3], maps:get(2, T)),
    ?assertEqual([4], maps:get(5, T)).

grid_network_test() ->
    T = topology:build(9, '2D'),
    ?assertEqual(lists:sort([2, 4]), lists:sort(maps:get(1, T))),
    ?assertEqual(lists:sort([2, 8, 4, 6]), lists:sort(maps:get(5, T))),
    ?assertEqual(lists:sort([6, 8]), lists:sort(maps:get(9, T))).

imperfect_grid_test() ->
    rand:seed(exsplus, {1, 2, 3}),
    T = topology:build(9, imp2D),
    lists:foreach(
      fun(Id) ->
          Neighbors = maps:get(Id, T),
          Base = maps:get(Id, topology:build(9, '2D')),
          ?assert(length(Neighbors) =:= length(Base) + 1 orelse
                  length(Base) =:= 8),
          ?assert(not lists:member(Id, Neighbors)),
          ?assertEqual(length(Neighbors), length(lists:usort(Neighbors)))
      end,
      lists:seq(1, 9)).

non_square_2d_rejected_test() ->
    ?assertError({invalid_node_count_for_2d_topology,
                  {expected_perfect_square, 10}},
                 topology:build(10, '2D')).

non_square_imp2d_rejected_test() ->
    ?assertError({invalid_node_count_for_2d_topology,
                  {expected_perfect_square, 10}},
                 topology:build(10, imp2D)).
