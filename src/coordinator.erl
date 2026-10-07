-module(coordinator).
-export([run/3]).

run(NumNodes, Topology, Algorithm) ->
    validate_input(NumNodes, Topology, Algorithm),
    NeighborMap = topology:build(NumNodes, Topology),
    StatisticsPid = statistics:start(NumNodes),
    ActorPids = start_actors(NumNodes, NeighborMap, StatisticsPid),
    Result = statistics:await_registration(StatisticsPid, 5000),
    stop_actors(ActorPids),
    statistics:stop(StatisticsPid),
    case Result of
        {ok, Actors} ->
            {ok, #{
                nodes => NumNodes,
                topology => Topology,
                algorithm => Algorithm,
                actors => Actors
            }};
        {error, timeout} ->
            {error, registration_timeout}
    end.

validate_input(NumNodes, Topology, Algorithm)
        when is_integer(NumNodes), NumNodes > 0 ->
    validate_topology(NumNodes, Topology),
    validate_algorithm(Algorithm);
validate_input(_, _, _) ->
    erlang:error({invalid_num_nodes, positive_integer_required}).

validate_topology(NumNodes, Topology) when Topology =:= '2D'; Topology =:= imp2D ->
    _ = topology:build(NumNodes, Topology),
    ok;
validate_topology(_NumNodes, Topology) when Topology =:= full; Topology =:= line ->
    ok;
validate_topology(_, Topology) ->
    erlang:error({invalid_topology, Topology}).

validate_algorithm(gossip) ->
    ok;
validate_algorithm('push-sum') ->
    ok;
validate_algorithm(Algorithm) ->
    erlang:error({invalid_algorithm, Algorithm}).

start_actors(NumNodes, NeighborMap, StatisticsPid) ->
    lists:map(
        fun(Id) ->
            actor:start(Id, maps:get(Id, NeighborMap), StatisticsPid)
        end,
        lists:seq(1, NumNodes)
    ).

stop_actors(Pids) ->
    lists:foreach(fun actor:stop/1, Pids).
