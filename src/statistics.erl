
-module(statistics).

-export([
    start/1,
    start/2,
    await_registration/2,
    await_convergence/2,
    get_report/2,
    set_start_time/2,
    stop/1
]).

start(ExpectedActors) ->
    start(ExpectedActors, gossip).

start(ExpectedActors, Algorithm) ->
    spawn(fun() -> init(ExpectedActors, Algorithm) end).

await_registration(Pid, Timeout) ->
    Pid ! {await_registration, self()},
    receive
        {registration_complete, Pid, Actors} ->
            {ok, Actors}
    after Timeout ->
        {error, timeout}
    end.

await_convergence(Pid, Timeout) ->
    Pid ! {await_convergence, self()},
    receive
        {convergence_complete, Pid, EndTime} ->
            {ok, EndTime};
        {convergence_failed, Pid, Reason} ->
            {error, Reason}
    after Timeout ->
        {error, timeout}
    end.

get_report(Pid, Timeout) ->
    Pid ! {get_report, self()},
    receive
        {statistics_report, Pid, Report} ->
            {ok, Report}
    after Timeout ->
        {error, timeout}
    end.

set_start_time(Pid, StartTime) ->
    Pid ! {set_start_time, StartTime}.

stop(Pid) ->
    Pid ! stop.

init(ExpectedActors, Algorithm) ->
    loop(ExpectedActors, Algorithm, #{}, undefined, undefined, #{}, undefined).

loop(Expected, Algorithm, Actors, RegWaiter, ConvWaiter, Reports, StartTime) ->
    receive
        {set_start_time, Time} ->
            loop(Expected, Algorithm, Actors, RegWaiter,
                 ConvWaiter, Reports, Time);

        {register, ActorPid, Id, Neighbors} ->
            NewActors = maps:put(
                Id, #{pid => ActorPid, neighbors => Neighbors}, Actors
            ),
            maybe_registration(Expected, Algorithm, NewActors,
                              RegWaiter, ConvWaiter, Reports, StartTime);

        {await_registration, From} ->
            case maps:size(Actors) =:= Expected of
                true ->
                    From ! {registration_complete, self(), Actors},
                    loop(Expected, Algorithm, Actors, undefined,
                         ConvWaiter, Reports, StartTime);
                false ->
                    loop(Expected, Algorithm, Actors, From,
                         ConvWaiter, Reports, StartTime)
            end;

        {gossip_update, _Pid, Id, Count} ->
            NewReports = maps:put({gossip_count, Id}, Count, Reports),
            maybe_converged(Expected, Algorithm, Actors, RegWaiter,
                            ConvWaiter, NewReports, StartTime);

        {push_sum_update, _Pid, Id, Estimate} ->
            NewReports = maps:put({estimate, Id}, Estimate, Reports),
            maybe_converged(Expected, Algorithm, Actors, RegWaiter,
                            ConvWaiter, NewReports, StartTime);

        {gossip_done, Pid, Id} ->
            NewReports = maps:put({done, Id}, Pid, Reports),
            maybe_converged(Expected, Algorithm, Actors, RegWaiter,
                            ConvWaiter, NewReports, StartTime);

        {push_sum_done, Pid, Id, Estimate} ->
            NewReports = maps:put({done, Id}, Pid, Reports),
            WithEstimate = maps:put({estimate, Id}, Estimate, NewReports),
            maybe_converged(Expected, Algorithm, Actors, RegWaiter,
                            ConvWaiter, WithEstimate, StartTime);

        {await_convergence, From} ->
            case maps:get(convergence_time, Reports, undefined) of
                undefined ->
                    loop(Expected, Algorithm, Actors, RegWaiter,
                         From, Reports, StartTime);
                EndTime ->
                    From ! {convergence_complete, self(), EndTime},
                    loop(Expected, Algorithm, Actors, RegWaiter,
                         undefined, Reports, StartTime)
            end;

        {convergence_timeout, _From} ->
            loop(Expected, Algorithm, Actors, RegWaiter,
                 ConvWaiter, Reports, StartTime);

        {get_report, From} ->
            From ! {statistics_report, self(), Reports},
            loop(Expected, Algorithm, Actors, RegWaiter,
                 ConvWaiter, Reports, StartTime);

        stop ->
            ok
    end.

maybe_registration(Expected, Algorithm, Actors, RegWaiter,
                   ConvWaiter, Reports, StartTime) ->
    case maps:size(Actors) =:= Expected andalso RegWaiter =/= undefined of
        true ->
            RegWaiter ! {registration_complete, self(), Actors},
            loop(Expected, Algorithm, Actors, undefined,
                 ConvWaiter, Reports, StartTime);
        false ->
            maybe_converged(Expected, Algorithm, Actors, RegWaiter,
                            ConvWaiter, Reports, StartTime)
    end.

maybe_converged(Expected, Algorithm, Actors, RegWaiter,
                ConvWaiter, Reports, StartTime) ->
    Converged =
        case Algorithm of
            gossip ->
                received_rumor_count(Reports) =:= Expected;
            'push-sum' ->
                done_count(Reports) =:= Expected
        end,
    case {Converged, maps:get(convergence_time, Reports, undefined)} of
        {true, undefined} ->
            EndTime = erlang:monotonic_time(microsecond),
            ElapsedTime =
                case StartTime of
                    undefined -> EndTime;
                    _ -> EndTime - StartTime
                end,
            notify_convergence(ConvWaiter, EndTime),
            FinalReports = maps:put(convergence_time, ElapsedTime, Reports),
            loop(Expected, Algorithm, Actors, RegWaiter,
                 undefined, FinalReports, StartTime);
        _ ->
            loop(Expected, Algorithm, Actors, RegWaiter,
                 ConvWaiter, Reports, StartTime)
    end.

received_rumor_count(Reports) ->
    maps:fold(
        fun
            ({gossip_count, _Id}, Count, Acc) when Count > 0 ->
                Acc + 1;
            (_, _, Acc) ->
                Acc
        end,
        0,
        Reports
    ).

done_count(Reports) ->
    maps:fold(
        fun
            ({done, _Id}, _Pid, Acc) -> Acc + 1;
            (_, _, Acc) -> Acc
        end,
        0,
        Reports
    ).

notify_convergence(undefined, _EndTime) ->
    ok;
notify_convergence(Waiter, EndTime) ->
    Waiter ! {convergence_complete, self(), EndTime}.
