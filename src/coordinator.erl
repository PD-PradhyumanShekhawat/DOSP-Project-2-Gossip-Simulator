
-module(coordinator).

-export([run/3, run/4]).

run(NumNodes, Topology, Algorithm) ->
    run(NumNodes, Topology, Algorithm, 10).

run(NumNodes, Topology, Algorithm, GossipThreshold) ->
    validate_input(NumNodes, Topology, Algorithm),
    validate_threshold(Algorithm, GossipThreshold),

    NeighborMap = topology:build(NumNodes, Topology),
    StatisticsPid = statistics:start(NumNodes, Algorithm),

    ActorPids =
        start_actors(
            NumNodes,
            NeighborMap,
            StatisticsPid,
            Algorithm,
            GossipThreshold
        ),

    case statistics:await_registration(StatisticsPid, 5000) of
        {ok, Actors} ->
            configure_actors(Actors, NeighborMap),

            StartTime = erlang:monotonic_time(microsecond),
            statistics:set_start_time(StatisticsPid, StartTime),
            seed_algorithm(Algorithm, ActorPids),

            Result = statistics:await_convergence(
                StatisticsPid,
                30000
            ),

            ReportResult = statistics:get_report(StatisticsPid, 1000),

            stop_actors(ActorPids),
            statistics:stop(StatisticsPid),

            finish_with_report(Result, ReportResult, StartTime);

        {error, timeout} ->
            stop_actors(ActorPids),
            statistics:stop(StatisticsPid),
            {error, registration_timeout}
    end.

seed_algorithm(gossip, [FirstActor | _]) ->
    FirstActor ! rumor;
seed_algorithm('push-sum', [FirstActor | _]) ->
    FirstActor ! {push_sum, 0.0, 0.0}.


finish_with_report({ok, EndTime}, {ok, Report}, StartTime) ->
    io:format("Statistics report: ~p~n", [Report]),
    {ok, EndTime - StartTime};
finish_with_report({ok, EndTime}, {error, Reason}, StartTime) ->
    io:format("Could not retrieve statistics report: ~p~n", [Reason]),
    {ok, EndTime - StartTime};
finish_with_report({error, Reason}, {ok, Report}, _StartTime) ->
    io:format("Convergence failed: ~p~n", [Reason]),
    io:format("Partial statistics report: ~p~n", [Report]),
    {error, Reason};
finish_with_report({error, Reason}, {error, ReportReason}, _StartTime) ->
    io:format("Convergence failed: ~p~n", [Reason]),
    io:format("Could not retrieve partial statistics: ~p~n", [ReportReason]),
    {error, Reason}.

validate_input(NumNodes, Topology, Algorithm)
        when is_integer(NumNodes), NumNodes > 0 ->
    validate_topology(NumNodes, Topology),
    validate_algorithm(Algorithm);
validate_input(_, _, _) ->
    erlang:error({invalid_num_nodes, positive_integer_required}).

validate_topology(NumNodes, Topology)
        when Topology =:= '2D'; Topology =:= imp2D ->
    _ = topology:build(NumNodes, Topology),
    ok;
validate_topology(_NumNodes, Topology)
        when Topology =:= full; Topology =:= line ->
    ok;
validate_topology(_, Topology) ->
    erlang:error({invalid_topology, Topology}).

validate_algorithm(gossip) ->
    ok;
validate_algorithm('push-sum') ->
    ok;
validate_algorithm(Algorithm) ->
    erlang:error({invalid_algorithm, Algorithm}).

validate_threshold(gossip, Threshold)
        when is_integer(Threshold), Threshold > 0 ->
    ok;
validate_threshold(gossip, Threshold) ->
    erlang:error({invalid_gossip_threshold, Threshold});
validate_threshold('push-sum', _Threshold) ->
    ok.

start_actors(NumNodes, NeighborMap, StatisticsPid, Algorithm, Threshold) ->
    [
        actor:start(
            Id,
            maps:get(Id, NeighborMap),
            StatisticsPid,
            Algorithm,
            Threshold
        )
        || Id <- lists:seq(1, NumNodes)
    ].

configure_actors(Actors, NeighborMap) ->
    maps:foreach(
        fun(Id, ActorInfo) ->
            NeighborIds = maps:get(Id, NeighborMap),
            NeighborPids = [
                maps:get(pid, maps:get(NeighborId, Actors))
                || NeighborId <- NeighborIds
            ],
            maps:get(pid, ActorInfo) ! {configure, NeighborPids}
        end,
        Actors
    ).

stop_actors(Pids) ->
    lists:foreach(fun actor:stop/1, Pids).
