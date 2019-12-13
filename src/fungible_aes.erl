-module(fungible_aes).

-include_lib("eqc/include/eqc.hrl").

-compile([export_all, nowarn_export_all]).
-import(sophia_eqc, [gen_account/1,
                     fate_nat/0,
                     fate_int/0,
                     fate_option/1,
                     caller/1,
                     creator/1]).

-import(eqc_statem, [eq/2]).

ct_file() ->
    Ebin = filename:dirname(code:which(sophia_eqc)),
    filename:join([Ebin, "..", "contracts", "fungible-token.aes"]).


%% Generated to simplify modeling, possibly dynamically done??
-record(state, {owner, total_supply, balances, meta_info}).

state_to_erlang(Fate) ->
    {tuple, {Owner,
             Total_supply,
             Balances,
             Meta_info}} = Fate,
    #state{owner = Owner, total_supply = Total_supply,
           balances = Balances,
           meta_info = Meta_info}.

%% User spec below

init_args(_ChainState) ->
    [string(), fate_nat(), non_empty(string()), fate_option(choose(-1, 10))].

init_valid(_ChainState, [Name, Decimal, Symbol, InitBalance] = Args) ->
    case InitBalance of
        {variant, [0, 1], 0, {}} -> true;
        {variant, [0, 1], 1, {X}} -> X >= 0
    end andalso size(Name) > 0.

%% Would be nice with a pretty printer fate representation -> Sophia
%% 'None' or 'Some(9)'
%% Can we generate ContractState structure?
balance_post(ChainState, #state{balances = Balances}, [Account], Res) ->
    case Res of
        {variant, [0, 1], 0, {}} ->
            not maps:is_key(Account, Balances);
        {variant, [0, 1], 1, {X}} ->
            eq(X, maps:get(Account, Balances, undefined))
    end.

balances_post(ChainState, #state{balances = Balances}, [], Res) ->
    eq(Balances, Res).

owner_post(ChainState, _ContractState, [], Res) ->
    eq(creator(ChainState), Res).

%% If we want to modify the test distribution, we may introduce our own generators
%% Note that we should generate FATE data
%% transfer_args(ChainState) ->
%%     [gen_account(ChainState), frequency([{0, fate_int()}, {49, fate_nat()}])].

%% If we want to test all arguments, but know some result in an error, we
%% can use _valid to flag this
transfer_valid(_, [_To, Amount]) ->
    Amount >= 0.


%% If we need the contract state for validation, we must add a postcondition
transfer_post(ChainState, #state{balances = Balances}, [To, Amount], Res) ->
    case Res of
        {revert, "BALANCE_ACCOUNT_NOT_EXISTENT"} ->
            not maps:is_key(caller(ChainState), Balances);
        {revert, "ACCOUNT_INSUFFICIENT_BALANCE"} ->
            maps:get(caller(ChainState), Balances, 0) < Amount;
        %% {revert, "NON_NEGATIVE_VALUE_REQUIRED"} ->
        %%     Amount < 0;
        {tuple, {}} -> true;
        _ -> eq(Res, ok)
    end.

%% We can collect features of the things we have tested
transfer_features(_S, _, _Args, Res) ->
    [{transfer, Res}].


%% -- invariant

invariant(_ChainState, #state{balances = Balances, total_supply = Supply}) ->
    Supply == lists:sum(maps:values(Balances)) andalso
        lists:all(fun(B) -> B >= 0 end, maps:values(Balances)).



%%% __________ GENERATORS _____________________________________


%% This should be part of aebytecode generators

string() ->
    elements([<<"ae">>, <<"piwo">>, <<"ta">>]).
