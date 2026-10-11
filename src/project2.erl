-module(project2).
-export([main/1]).

main([NumNodesArg, TopologyArg, AlgorithmArg]) ->
    main([NumNodesArg, TopologyArg, AlgorithmArg, "0.0"]);
main([NumNodesArg, TopologyArg, AlgorithmArg, FailureArg]) ->
    NumNodes = parse_num_nodes(NumNodesArg),
    Topology = parse_topology(TopologyArg),
    Algorithm = parse_algorithm(AlgorithmArg),
    FailureProbability = parse_probability(FailureArg),
    case coordinator:run(NumNodes, Topology, Algorithm, 10, FailureProbability) of
        {ok, Duration} ->
            io:format(
                "Nodes: ~p~nTopology: ~s~nAlgorithm: ~s~nConvergence time: ~p microseconds~n",
                [NumNodes, topology_name(Topology), algorithm_name(Algorithm), Duration]
            ),
            ok;
        {error, Reason} ->
            io:format("Simulation failed: ~p~n", [Reason]),
            {error, Reason}
    end;
main(_) ->
    io:format(
        "Usage: project2 numNodes topology algorithm [failure_probability]~n"
        "topology: full | 2D | line | imp2D~n"
        "algorithm: gossip | push-sum~n"
        "failure_probability: 0.0 to 1.0 (default 0.0)~n"
    ),
    {error, invalid_arguments}.

parse_num_nodes(Value) ->
    case string:to_integer(Value) of
        {N, ""} when N > 0 ->
            N;
        _ ->
            erlang:error({invalid_num_nodes, Value})
    end.

parse_topology(Value) ->
    case string:lowercase(Value) of
        "full" -> full;
        "2d" -> '2D';
        "line" -> line;
        "imp2d" -> imp2D;
        _ -> erlang:error({invalid_topology, Value})
    end.

parse_algorithm(Value) ->
    case string:lowercase(Value) of
        "gossip" -> gossip;
        "push-sum" -> 'push-sum';
        _ -> erlang:error({invalid_algorithm, Value})
    end.

topology_name('2D') -> "2D";
topology_name(Topology) -> atom_to_list(Topology).

algorithm_name('push-sum') -> "push-sum";
algorithm_name(Algorithm) -> atom_to_list(Algorithm).

parse_probability(Value) ->
    try list_to_float(Value) of
        P when P >= 0.0, P =< 1.0 -> P;
        _ -> erlang:error({invalid_failure_probability, Value})
    catch
        error:Reason -> erlang:error({invalid_failure_probability, {Value, Reason}})
    end.
