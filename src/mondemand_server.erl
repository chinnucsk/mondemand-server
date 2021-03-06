-module (mondemand_server).

-include_lib ("lwes/include/lwes.hrl").

-behaviour (gen_server).

%% API
-export ([ start_link/1,
           process_event/2 ]).

%% gen_server callbacks
-export ([ init/1,
           handle_call/3,
           handle_cast/2,
           handle_info/2,
           terminate/2,
           code_change/3
         ]).

-record (state, { listener, dispatch }).
-record (listener_state, { dispatch }).

%%====================================================================
%% API
%%====================================================================
start_link (Config) ->
  error_logger:info_msg ("mondemand_server:start_link(~p)",[Config]),
  gen_server:start_link ( { local, ?MODULE }, ?MODULE, [Config], []).

process_event (Event, State = #listener_state { dispatch = Dispatch }) ->
  % call handlers for each event type
  EventName = lwes_event:peek_name_from_udp (Event),
  case dict:find (EventName, Dispatch) of
    {ok, V} -> [ M:process(Event) || M <- V ];
    error ->
      error_logger:error_msg ("No handler for event ~p in dispatch~n~p",[EventName, Dispatch])
  end,
  State.

%%====================================================================
%% gen_server callbacks
%%====================================================================
init ([Dispatch]) ->
  % lwes listener config
  { ok, LwesConfig } = application:get_env (mondemand_server, listener),

  % I want terminate to be called
  process_flag (trap_exit, true),

  % open lwes channel
  {ok, Channel} = lwes:open (listener, LwesConfig),
  ok = lwes:listen (Channel, fun process_event/2, raw,
                    #listener_state{ dispatch = dict:from_list (Dispatch)}),

  { ok, #state { dispatch = Dispatch, listener = Channel } }.

handle_call (Request, From, State) ->
  error_logger:warning_msg ("Unrecognized call ~p from ~p~n",[Request, From]),
  { reply, ok, State }.

handle_cast (Request, State) ->
  error_logger:warning_msg ("Unrecognized cast ~p~n",[Request]),
  { noreply, State }.

handle_info (Request, State) ->
  error_logger:warning_msg ("Unrecognized info ~p~n",[Request]),
  {noreply, State}.

terminate (_Reason, #state { listener = Channel }) ->
  lwes:close (Channel),
  ok.

code_change (_OldVsn, State, _Extra) ->
  {ok, State}.

