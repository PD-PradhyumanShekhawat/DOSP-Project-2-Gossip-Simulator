-module(actor_tests).

-include_lib("eunit/include/eunit.hrl").

actor_registration_test() ->
    NeighborMap = topology:build(4, full),
    StatisticsPid = statistics:start(4),

    ActorPids =
        [
            actor:start(
                Id,
                maps:get(Id, NeighborMap),
                StatisticsPid,
                gossip
            )
            || Id <- lists:seq(1, 4)
        ],

    {ok, Actors} =
        statistics:await_registration(
            StatisticsPid,
            5000
        ),

    ?assertEqual(4, maps:size(Actors)),

    lists:foreach(
        fun(Pid) -> actor:stop(Pid) end,
        ActorPids
    ),

    statistics:stop(StatisticsPid).