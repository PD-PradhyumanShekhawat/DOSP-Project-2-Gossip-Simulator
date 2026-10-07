-module(actor_tests).

-include_lib("eunit/include/eunit.hrl").

actor_registration_test() ->
    {ok, Summary} = coordinator:run(4, full, gossip),
    ?assertEqual(4, maps:size(Summary)),
    Actors = maps:get(actors, Summary),
    ?assertEqual(4, maps:size(Actors)),
    lists:foreach(
        fun(Id) ->
            Actor = maps:get(Id, Actors),
            ?assert(is_pid(maps:get(pid, Actor))),
            ?assertEqual([N || N <- lists:seq(1, 4), N =/= Id],
                         lists:sort(maps:get(neighbors, Actor)))
        end,
        lists:seq(1, 4)
    ).
