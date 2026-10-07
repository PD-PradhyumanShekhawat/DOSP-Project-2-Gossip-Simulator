-module(topology).

-export([build/2, neighbors/3, is_perfect_square/1]).

-type node_id() :: pos_integer().
-type topology() :: full | line | '2D' | imp2D.

-spec build(pos_integer(), topology()) -> #{node_id() => [node_id()]}.
build(N, Topology) when is_integer(N), N > 0 ->
    case Topology of
        '2D' ->
            ensure_perfect_square(N),
            build_topology(N, Topology);
        imp2D ->
            ensure_perfect_square(N),
            build_topology(N, Topology);
        full ->
            build_topology(N, Topology);
        line ->
            build_topology(N, Topology)
    end.

-spec neighbors(node_id(), pos_integer(), topology()) -> [node_id()].
neighbors(Id, N, Topology) ->
    maps:get(Id, build(N, Topology)).

-spec is_perfect_square(pos_integer()) -> boolean().
is_perfect_square(N) when is_integer(N), N > 0 ->
    Side = trunc(math:sqrt(N)),
    Side * Side =:= N.

build_topology(N, full) ->
    maps:from_list([
        {Id, [Other || Other <- lists:seq(1, N), Other =/= Id]}
     || Id <- lists:seq(1, N)]);
build_topology(N, line) ->
    maps:from_list([
        {Id, line_neighbors(Id, N)}
     || Id <- lists:seq(1, N)]);
build_topology(N, '2D') ->
    maps:from_list([
        {Id, grid_neighbors(Id, N)}
     || Id <- lists:seq(1, N)]);
build_topology(N, imp2D) ->
    Base = maps:from_list([
        {Id, grid_neighbors(Id, N)}
     || Id <- lists:seq(1, N)]),
    maps:map(fun(Id, Neighbors) ->
        ExtraCandidates = [
            Candidate || Candidate <- lists:seq(1, N),
                         Candidate =/= Id,
                         not lists:member(Candidate, Neighbors)
        ],
        case ExtraCandidates of
            [] -> Neighbors;
            _ -> [pick_random(ExtraCandidates) | Neighbors]
        end
    end, Base).

line_neighbors(Id, N) ->
    Left = case Id > 1 of true -> [Id - 1]; false -> [] end,
    Right = case Id < N of true -> [Id + 1]; false -> [] end,
    Left ++ Right.

grid_neighbors(Id, N) ->
    Side = trunc(math:sqrt(N)),
    Row = (Id - 1) div Side,
    Col = (Id - 1) rem Side,
    Candidates = [
        {Row - 1, Col},
        {Row + 1, Col},
        {Row, Col - 1},
        {Row, Col + 1}
    ],
    lists:filtermap(fun({R, C}) ->
        case R >= 0 andalso R < Side andalso C >= 0 andalso C < Side of
            true -> {true, R * Side + C + 1};
            false -> false
        end
    end, Candidates).

pick_random(List) ->
    lists:nth(rand:uniform(length(List)), List).

ensure_perfect_square(N) ->
    case is_perfect_square(N) of
        true -> ok;
        false ->
            error({invalid_node_count_for_2d_topology,
                   {expected_perfect_square, N}})
    end.
