-module(actor).
-export([start/4, start/5, start/6, stop/1]).

-define(PUSH_SUM_EPSILON, 1.0e-10).
-define(PUSH_SUM_STABLE_ROUNDS, 3).
-define(DEFAULT_GOSSIP_THRESHOLD, 10).

start(Id, Neighbors, StatisticsPid, gossip) ->
    start(Id, Neighbors, StatisticsPid, gossip, ?DEFAULT_GOSSIP_THRESHOLD, 0.0);
start(Id, Neighbors, StatisticsPid, 'push-sum') ->
    start(Id, Neighbors, StatisticsPid, 'push-sum', undefined, 0.0);
start(_Id, _Neighbors, _StatisticsPid, Algorithm) ->
    erlang:error({algorithm_not_implemented, Algorithm}).

start(Id, Neighbors, StatisticsPid, Algorithm, Threshold) ->
    start(Id, Neighbors, StatisticsPid, Algorithm, Threshold, 0.0).

start(Id, Neighbors, StatisticsPid, gossip, Threshold, P)
        when is_integer(Threshold), Threshold > 0,
             is_number(P), P >= 0, P =< 1 ->
    spawn(fun() ->
        seed_random(),
        StatisticsPid ! {register, self(), Id, Neighbors},
        gossip_loop(Id, Neighbors, StatisticsPid, 0, false, Threshold, float(P))
    end);
start(Id, Neighbors, StatisticsPid, 'push-sum', _Threshold, P)
        when is_number(P), P >= 0, P =< 1 ->
    spawn(fun() ->
        seed_random(),
        StatisticsPid ! {register, self(), Id, Neighbors},
        push_sum_loop(
            Id, Neighbors, StatisticsPid,
            float(Id), 1.0, undefined, 0, false, float(P)
        )
    end);
start(_Id, _Neighbors, _StatisticsPid, gossip, Threshold, _P)
        when not (is_integer(Threshold) andalso Threshold > 0) ->
    erlang:error({invalid_gossip_threshold, Threshold});
start(_Id, _Neighbors, _StatisticsPid, _Algorithm, _Threshold, P) ->
    erlang:error({invalid_failure_probability, P}).

stop(Pid) ->
    Pid ! stop.

gossip_loop(Id, Neighbors, StatisticsPid, Count, Done, Threshold, P) ->
    receive
        {configure, ConfiguredNeighbors} ->
            gossip_loop(Id, ConfiguredNeighbors, StatisticsPid,
                        Count, Done, Threshold, P);

        rumor when Done =:= false ->
            NewCount = Count + 1,
            StatisticsPid ! {gossip_update, self(), Id, NewCount},
            case NewCount >= Threshold of
                true ->
                    StatisticsPid ! {gossip_done, self(), Id},
                    gossip_loop(Id, Neighbors, StatisticsPid,
                                NewCount, true, Threshold, P);
                false ->
                    send_rumor(Neighbors, P),
                    gossip_loop(Id, Neighbors, StatisticsPid,
                                NewCount, false, Threshold, P)
            end;

        rumor ->
            gossip_loop(Id, Neighbors, StatisticsPid,
                        Count, Done, Threshold, P);

        stop ->
            ok
    end.

push_sum_loop(Id, Neighbors, StatisticsPid,
              S, W, PreviousEstimate, StableRounds, ReportedDone, P) ->
    receive
        {configure, ConfiguredNeighbors} ->
            push_sum_loop(Id, ConfiguredNeighbors, StatisticsPid,
                          S, W, PreviousEstimate, StableRounds, ReportedDone, P);

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

            NowDone = ReportedDone orelse
                      NewStableRounds >= ?PUSH_SUM_STABLE_ROUNDS,

            case {NowDone, ReportedDone} of
                {true, false} ->
                    StatisticsPid ! {push_sum_done, self(), Id, Estimate};
                _ ->
                    ok
            end,

            case Neighbors of
                [] ->
                    %% No surviving connection: retain all local mass.
                    push_sum_loop(Id, Neighbors, StatisticsPid,
                                  NewS, NewW, Estimate,
                                  NewStableRounds, NowDone, P);
                _ ->
                    send_push_sum(Neighbors, NewS / 2, NewW / 2, P),
                    push_sum_loop(Id, Neighbors, StatisticsPid,
                                  NewS / 2, NewW / 2, Estimate,
                                  NewStableRounds, NowDone, P)
            end;

        stop ->
            ok
    end.

send_rumor(Neighbors, P) ->
    send_to_random_neighbor(Neighbors, rumor, P).

send_push_sum(Neighbors, S, W, P) ->
    send_to_random_neighbor(Neighbors, {push_sum, S, W}, P).

%% A transient link failure independently drops each attempted transmission.
send_to_random_neighbor([], _Message, _P) ->
    ok;
send_to_random_neighbor(Neighbors, Message, _P) ->
    %% Connection failures are represented by the filtered neighbor graph.
    %% Do not independently drop messages here.
    Neighbor = lists:nth(rand:uniform(length(Neighbors)), Neighbors),
    Neighbor ! Message.

seed_random() ->
    rand:seed(
        exsplus,
        {
            erlang:phash2(self()),
            erlang:unique_integer([positive]),
            erlang:phash2(erlang:monotonic_time())
        }
    ).
