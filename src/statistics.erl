-module(statistics).
-export([start/1, await_registration/2, stop/1]).

start(ExpectedActors) ->
    spawn(fun() -> init(ExpectedActors) end).

await_registration(Pid, Timeout) ->
    Pid ! {await_registration, self()},
    receive
        {registration_complete, Pid, Summary} ->
            {ok, Summary}
    after Timeout ->
        {error, timeout}
    end.

stop(Pid) ->
    Pid ! stop.

init(ExpectedActors) ->
    loop(ExpectedActors, #{}, undefined).

loop(ExpectedActors, Actors, Waiter) ->
    case maps:size(Actors) =:= ExpectedActors andalso Waiter =/= undefined of
        true ->
            Waiter ! {registration_complete, self(), Actors},
            loop(ExpectedActors, Actors, undefined);
        false ->
            receive
                {register, ActorPid, Id, Neighbors} ->
                    NewActors = maps:put(Id, #{pid => ActorPid, neighbors => Neighbors}, Actors),
                    loop(ExpectedActors, NewActors, Waiter);
                {await_registration, From} ->
                    loop(ExpectedActors, Actors, From);
                stop ->
                    ok
            end
    end.
