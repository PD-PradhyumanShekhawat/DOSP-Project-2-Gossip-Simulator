
-module(actor).
-export([start/4, start/5, stop/1]).

-define(PUSH_SUM_EPSILON, 1.0e-10).
-define(PUSH_SUM_STABLE_ROUNDS, 3).
-define(DEFAULT_GOSSIP_THRESHOLD, 10).

start(Id, Neighbors, StatisticsPid, gossip) ->
    start(Id, Neighbors, StatisticsPid, gossip, ?DEFAULT_GOSSIP_THRESHOLD);
start(Id, Neighbors, StatisticsPid, 'push-sum') ->
    start(Id, Neighbors, StatisticsPid, 'push-sum', undefined);
start(_Id, _Neighbors, _StatisticsPid, Algorithm) ->
    erlang:error({algorithm_not_implemented, Algorithm}).

start(Id, Neighbors, StatisticsPid, gossip, Threshold)
        when is_integer(Threshold), Threshold > 0 ->
    spawn(fun() ->
        seed_random(),
        StatisticsPid ! {register, self(), Id, Neighbors},
        gossip_loop(Id, Neighbors, StatisticsPid, 0, false, Threshold)
    end);
start(Id, Neighbors, StatisticsPid, 'push-sum', _Threshold) ->
    spawn(fun() ->
        seed_random(),
        StatisticsPid ! {register, self(), Id, Neighbors},
        push_sum_loop(
            Id, Neighbors, StatisticsPid,
            float(Id), 1.0, undefined, 0, false
        )
    end);
start(_Id, _Neighbors, _StatisticsPid, gossip, Threshold) ->
    erlang:error({invalid_gossip_threshold, Threshold});
start(_Id, _Neighbors, _StatisticsPid, Algorithm, _Threshold) ->
    erlang:error({algorithm_not_implemented, Algorithm}).

stop(Pid) ->
    Pid ! stop.

gossip_loop(Id, Neighbors, StatisticsPid, Count, Done, Threshold) ->
    receive
        {configure, ConfiguredNeighbors} ->
            gossip_loop(
                Id, ConfiguredNeighbors, StatisticsPid,
                Count, Done, Threshold
            );

        rumor when Done =:= false ->
            NewCount = Count + 1,
            StatisticsPid ! {gossip_update, self(), Id, NewCount},
            case NewCount >= Threshold of
                true ->
                    StatisticsPid ! {gossip_done, self(), Id},
                    gossip_loop(
                        Id, Neighbors, StatisticsPid,
                        NewCount, true, Threshold
                    );
                false ->
                    send_rumor(Neighbors),
                    gossip_loop(
                        Id, Neighbors, StatisticsPid,
                        NewCount, false, Threshold
                    )
            end;

        rumor ->
            gossip_loop(Id, Neighbors, StatisticsPid, Count, Done, Threshold);

        stop ->
            ok
    end.

push_sum_loop(
    Id, Neighbors, StatisticsPid,
    S, W, PreviousEstimate, StableRounds, ReportedDone
) ->
    receive
        {configure, ConfiguredNeighbors} ->
            push_sum_loop(
                Id, ConfiguredNeighbors, StatisticsPid,
                S, W, PreviousEstimate, StableRounds, ReportedDone
            );

        {push_sum, ReceivedS, ReceivedW} ->
            NewS = S + ReceivedS,
            NewW = W + ReceivedW,
            Estimate = NewS / NewW,

            NewStableRounds =
                case PreviousEstimate of
                    undefined -> 0;
                    Previous ->
                        case abs(Estimate - Previous) < ?PUSH_SUM_EPSILON of
                            true -> StableRounds + 1;
                            false -> 0
                        end
                end,

            StatisticsPid ! {push_sum_update, self(), Id, Estimate},

            NowDone =
                ReportedDone orelse
                NewStableRounds >= ?PUSH_SUM_STABLE_ROUNDS,

            case {NowDone, ReportedDone} of
                {true, false} ->
                    StatisticsPid !
                        {push_sum_done, self(), Id, Estimate};
                _ ->
                    ok
            end,

            send_push_sum(Neighbors, NewS / 2, NewW / 2),

            push_sum_loop(
                Id, Neighbors, StatisticsPid,
                NewS / 2, NewW / 2, Estimate, NewStableRounds, NowDone
            );

        stop ->
            ok
    end.

send_rumor([]) ->
    ok;
send_rumor(Neighbors) ->
    Neighbor = lists:nth(rand:uniform(length(Neighbors)), Neighbors),
    Neighbor ! rumor.

send_push_sum([], _S, _W) ->
    ok;
send_push_sum(Neighbors, S, W) ->
    Neighbor = lists:nth(rand:uniform(length(Neighbors)), Neighbors),
    Neighbor ! {push_sum, S, W}.

seed_random() ->
    rand:seed(
        exsplus,
        {
            erlang:phash2(self()),
            erlang:unique_integer([positive]),
            erlang:phash2(erlang:monotonic_time())
        }
    ).
