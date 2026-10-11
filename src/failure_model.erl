-module(failure_model).

-export([apply/2, is_connected/1]).

%% A connection is an undirected edge. For imperfect 2D, this also
%% makes randomly added connections available from both endpoints.
%% Returns {FilteredNeighborMap, NumberOfFailedConnections}.
apply(NeighborMap, P)
        when is_number(P), P >= 0, P =< 1 ->
    seed_random(),
    Edges = undirected_edges(NeighborMap),
    {Surviving, Failed} = lists:foldl(
        fun(Edge, {Keep, Drop}) ->
            case rand:uniform() >= P of
                true  -> {[Edge | Keep], Drop};
                false -> {Keep, [Edge | Drop]}
            end
        end,
        {[], []},
        Edges
    ),
    Filtered = maps:map(
        fun(Id, _OldNeighbors) ->
            lists:sort([
                case Id of A -> B; _ -> A end
                || {A, B} <- Surviving,
                   A =:= Id orelse B =:= Id
            ])
        end,
        NeighborMap
    ),
    {Filtered, length(Failed)}.

undirected_edges(NeighborMap) ->
    lists:usort([
        {min(A, B), max(A, B)}
        || {A, Neighbors} <- maps:to_list(NeighborMap),
           B <- Neighbors,
           A =/= B
    ]).

is_connected(NeighborMap) when map_size(NeighborMap) =:= 0 ->
    false;
is_connected(NeighborMap) ->
    [First | _] = maps:keys(NeighborMap),
    Reached = visit([First], NeighborMap, #{}),
    map_size(Reached) =:= map_size(NeighborMap).

visit([], _NeighborMap, Seen) ->
    Seen;
visit([Id | Rest], NeighborMap, Seen) ->
    case maps:is_key(Id, Seen) of
        true ->
            visit(Rest, NeighborMap, Seen);
        false ->
            Neighbors = maps:get(Id, NeighborMap, []),
            visit(Neighbors ++ Rest, NeighborMap, maps:put(Id, true, Seen))
    end.

seed_random() ->
    rand:seed(
        exsplus,
        {
            erlang:phash2(self()),
            erlang:unique_integer([positive]),
            erlang:phash2(erlang:monotonic_time())
        }
    ).
