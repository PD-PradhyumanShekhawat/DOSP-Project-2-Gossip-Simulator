-module(project2).

-export([main/1]).

main([NumNodesArg, TopologyArg, AlgorithmArg]) ->
    case parse_num_nodes(NumNodesArg) of
        {ok, NumNodes} ->
            case parse_topology(TopologyArg) of
                {ok, Topology} ->
                    case parse_algorithm(AlgorithmArg) of
                        {ok, Algorithm} ->
                            io:format(
                              "Project 2 configuration: nodes=~p topology=~p algorithm=~p~n",
                              [NumNodes, Topology, Algorithm]),
                            ok;
                        error -> usage()
                    end;
                error -> usage()
            end;
        error -> usage()
    end;
main(_) ->
    usage().

parse_num_nodes(String) ->
    case string:to_integer(String) of
        {N, ""} when N > 0 -> {ok, N};
        _ -> error
    end.

parse_topology("full") -> {ok, full};
parse_topology("2D") -> {ok, '2D'};
parse_topology("line") -> {ok, line};
parse_topology("imp2D") -> {ok, imp2D};
parse_topology(_) -> error.

parse_algorithm("gossip") -> {ok, gossip};
parse_algorithm("push-sum") -> {ok, 'push-sum'};
parse_algorithm("push_sum") -> {ok, 'push-sum'};
parse_algorithm(_) -> error.

usage() ->
    io:format(
      "Usage: project2 numNodes topology algorithm~n"
      "  topology: full | 2D | line | imp2D~n"
      "  algorithm: gossip | push-sum~n",
      []).
