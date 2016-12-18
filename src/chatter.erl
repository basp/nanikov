-module(chatter).

-compile(export_all).

start(Channel) ->
    spawn(fun() -> loop(Channel) end).

loop(Channel) ->
    MinSleep = 5 * 60 * 1000,
    MaxSleep = 10 * 60 * 1000,
    Zzz = MinSleep + rand:uniform(MaxSleep),
    sleep(Zzz),
    Tokens = markov_server:generate(13),
    Msg = string:join(Tokens, " "),
    nani_bot:say(Channel, Msg),
    loop(Channel).

sleep(Zzz) ->
    receive
        after Zzz -> true
    end.