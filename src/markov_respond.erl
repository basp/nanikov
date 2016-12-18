-module(markov_respond).

-behavior(gen_event).

%% API
-export([add_handler/0, delete_handler/0]).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2, handle_info/2, 
         terminate/2, code_change/3]).

%%%============================================================================
%%% API
%%%============================================================================
add_handler() ->
    nani_event:add_handler(?MODULE, []).

delete_handler() ->
    nani_event:delete_handler(?MODULE, []).

%%%============================================================================
%%% gen_event callbacks
%%%============================================================================
init([]) ->
    {ok, []}.

handle_event({privmsg, {Nick, Alts}, _From, To, Text}, State) ->
    % Let's learn some new vocab
    markov_server:seed(Text),

    Aliases = [Nick | Alts],
    case matches_any(Text, [global, caseless], Aliases) of
        true -> 
            Tokens = markov_server:generate(13),
            Msg = string:join(Tokens, " "),
            nani_bot:say(To, Msg),
            {ok, State};
        _ ->
            {ok, State}
    end;

handle_event(_Event, State) ->
    {ok, State}.

handle_call(_Request, State) ->
    Reply = ok,
    {ok, Reply, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%============================================================================
%%% gen_event callbacks
%%%============================================================================
matches_any(_Text, _Opts, []) -> false;

matches_any(Text, Opts, [H|T]) ->
    case re:run(Text, H, Opts) of
        {match, _} -> true;
        _ -> matches_any(Text, Opts, T)
    end.