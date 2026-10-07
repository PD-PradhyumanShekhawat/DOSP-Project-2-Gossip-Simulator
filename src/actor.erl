-module(actor).
-export([start/3, stop/1]).

start(Id, Neighbors, StatisticsPid) ->
    spawn(fun() -> init(Id, Neighbors, StatisticsPid) end).

stop(Pid) ->
    Pid ! stop.

init(Id, Neighbors, StatisticsPid) ->
    StatisticsPid ! {register, self(), Id, Neighbors},
    loop(Id, Neighbors, StatisticsPid).

loop(Id, Neighbors, StatisticsPid) ->
    receive
        {ping, From} ->
            From ! {pong, Id},
            loop(Id, Neighbors, StatisticsPid);
        stop ->
            ok
    end.
