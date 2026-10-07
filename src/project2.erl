-module(project2).
-export([main/1]).

main([NumNodesArg, TopologyArg, AlgorithmArg]) ->
    NumNodes = parse_num_nodes(NumNodesArg),
    Topology = parse_topology(TopologyArg),
    Algorithm = parse_algorithm(AlgorithmArg),
    case coordinator:run(NumNodes, Topology, Algorithm) of
        {ok, _Summary} ->
            io:format(
                "Actor infrastructure ready: ~p nodes, ~p topology, ~p algorithm.~n",
                [NumNodes, topology_name(Topology), algorithm_name(Algorithm)]
            ),
            ok;
        {error, Reason} ->
            erlang:error(Reason)
    end;
main(_) ->
    io:format(
        "Usage: project2 numNodes topology algorithm~n"
        "topology: full | 2D | line | imp2D~n"
        "algorithm: gossip | push-sum~n"
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
