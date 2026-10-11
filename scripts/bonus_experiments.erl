-module(bonus_experiments).
-export([main/0]).

main() ->
    ok = filelib:ensure_dir("results/bonus/placeholder"),
    {ok, File} = file:open("results/bonus/failure_experiments.csv", [write]),
    io:format(File,
        "topology,nodes,algorithm,failure_probability,trial,status,convergence_time_us,reason~n",
        []),

    Topologies = [{full, 9}, {'2D', 9}],
    Algorithms = [gossip, 'push-sum'],
    Probabilities = [0.0, 0.1, 0.25, 0.5, 0.75, 1.0],
    Trials = lists:seq(1, 10),

    Total = length(Topologies) * length(Algorithms) *
            length(Probabilities) * length(Trials),
    io:format("Running ~p trials with permanent undirected connection failures.~n",
              [Total]),

    _ = lists:foldl(
        fun({Topology, N}, Index0) ->
            lists:foldl(
                fun(Algorithm, Index1) ->
                    lists:foldl(
                        fun(P, Index2) ->
                            lists:foldl(
                                fun(Trial, Index3) ->
                                    Result = run_trial(N, Topology, Algorithm, P),
                                    write_result(File, Topology, N, Algorithm,
                                                 P, Trial, Result),
                                    case Index3 rem 20 of
                                        0 -> io:format("Completed ~p/~p trials~n",
                                                       [Index3, Total]);
                                        _ -> ok
                                    end,
                                    Index3 + 1
                                end,
                                Index2,
                                Trials
                            )
                        end,
                        Index1,
                        Probabilities
                    )
                end,
                Index0,
                Algorithms
            )
        end,
        1,
        Topologies
    ),

    ok = file:close(File),
    io:format("Wrote results/bonus/failure_experiments.csv (~p trials).~n",
              [Total]),
    ok.

run_trial(N, Topology, Algorithm, P) ->
    try coordinator:run(N, Topology, Algorithm, 10, P, 5000) of
        {ok, TimeUs} ->
            {success, TimeUs, ""};
        {error, {disconnected_network, FailedEdges}} ->
            {disconnected, "", integer_to_list(FailedEdges)};
        {error, timeout} ->
            {timeout, "", "convergence_timeout"};
        {error, Reason} ->
            {error, "", lists:flatten(io_lib:format("~p", [Reason]))}
    catch
        Class:Reason ->
            {error, "", lists:flatten(io_lib:format("~p:~p", [Class, Reason]))}
    end.

write_result(File, Topology, N, Algorithm, P, Trial,
             {Status, Time, Reason}) ->
    TimeText = case Time of
        "" -> "";
        Value when is_integer(Value) -> integer_to_list(Value);
        Value -> lists:flatten(io_lib:format("~p", [Value]))
    end,
    ReasonText = case Reason of
        "" -> "";
        Value2 when is_list(Value2) -> Value2;
        Value2 -> lists:flatten(io_lib:format("~p", [Value2]))
    end,
    io:format(File, "~s,~p,~s,~p,~p,~s,~s,~s~n",
        [topology_name(Topology), N, algorithm_name(Algorithm),
         P, Trial, atom_to_list(Status), TimeText, ReasonText]).

topology_name('2D') -> "2D";
topology_name(Topology) -> atom_to_list(Topology).

algorithm_name('push-sum') -> "push-sum";
algorithm_name(Algorithm) -> atom_to_list(Algorithm).
