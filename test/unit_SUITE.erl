%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License at
%% http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%% License for the specific language governing rights and limitations
%% under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2016 Pivotal Software, Inc.  All rights reserved.
%%

-module(unit_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("proper/include/proper.hrl").

-compile(export_all).

all() ->
    [
      {group, parallel_tests}
    ].

groups() ->
    [
      {parallel_tests, [parallel], [
        encrypt_decrypt,
        encrypt_decrypt_term,
        version_equivalence,
        version_minor_equivalence_properties,
        version_comparison
      ]}
    ].

init_per_group(_, Config) -> Config.
end_per_group(_, Config) -> Config.

encrypt_decrypt(_Config) ->
    %% Take all available block ciphers.
    Hashes = rabbit_pbe:supported_hashes(),
    Ciphers = rabbit_pbe:supported_ciphers(),
    %% For each cipher, try to encrypt and decrypt data sizes from 0 to 64 bytes
    %% with a random passphrase.
    _ = [begin
             PassPhrase = crypto:strong_rand_bytes(16),
             Iterations = rand:uniform(100),
             Data = crypto:strong_rand_bytes(64),
             [begin
                  Expected = binary:part(Data, 0, Len),
                  Enc = rabbit_pbe:encrypt(C, H, Iterations, PassPhrase, Expected),
                  Expected = iolist_to_binary(rabbit_pbe:decrypt(C, H, Iterations, PassPhrase, Enc))
              end || Len <- lists:seq(0, byte_size(Data))]
         end || H <- Hashes, C <- Ciphers],
    ok.

encrypt_decrypt_term(_Config) ->
    %% Take all available block ciphers.
    Hashes = rabbit_pbe:supported_hashes(),
    Ciphers = rabbit_pbe:supported_ciphers(),
    %% Different Erlang terms to try encrypting.
    DataSet = [
        10000,
        [5672],
        [{"127.0.0.1", 5672},
            {"::1",       5672}],
        [{connection, info}, {channel, info}],
        [{cacertfile,           "/path/to/testca/cacert.pem"},
            {certfile,             "/path/to/server/cert.pem"},
            {keyfile,              "/path/to/server/key.pem"},
            {verify,               verify_peer},
            {fail_if_no_peer_cert, false}],
        [<<".*">>, <<".*">>, <<".*">>]
    ],
    _ = [begin
             PassPhrase = crypto:strong_rand_bytes(16),
             Iterations = rand:uniform(100),
             Enc = rabbit_pbe:encrypt_term(C, H, Iterations, PassPhrase, Data),
             Data = rabbit_pbe:decrypt_term(C, H, Iterations, PassPhrase, Enc)
         end || H <- Hashes, C <- Ciphers, Data <- DataSet],
    ok.

version_equivalence(_Config) ->
    true = rabbit_misc:version_minor_equivalent("3.0.0", "3.0.0"),
    true = rabbit_misc:version_minor_equivalent("3.0.0", "3.0.1"),
    true = rabbit_misc:version_minor_equivalent("%%VSN%%", "%%VSN%%"),
    true = rabbit_misc:version_minor_equivalent("3.0.0", "3.0"),
    true = rabbit_misc:version_minor_equivalent("3.0.0", "3.0.0.1"),
    true = rabbit_misc:version_minor_equivalent("3.0.0.1", "3.0.0.3"),
    true = rabbit_misc:version_minor_equivalent("3.0.0.1", "3.0.1.3"),
    true = rabbit_misc:version_minor_equivalent("3.0.0", "3.0.foo"),
    false = rabbit_misc:version_minor_equivalent("3.0.0", "3.1.0"),
    false = rabbit_misc:version_minor_equivalent("3.0.0.1", "3.1.0.1"),

    false = rabbit_misc:version_minor_equivalent("3.5.7", "3.6.7"),
    false = rabbit_misc:version_minor_equivalent("3.6.5", "3.6.6"),
    false = rabbit_misc:version_minor_equivalent("3.6.6", "3.7.0"),
    true = rabbit_misc:version_minor_equivalent("3.6.7", "3.6.6"),

    true = rabbit_misc:version_minor_equivalent(<<"3.0.0">>, <<"3.0.0">>),
    true = rabbit_misc:version_minor_equivalent(<<"3.0.0">>, <<"3.0.1">>),
    true = rabbit_misc:version_minor_equivalent(<<"%%VSN%%">>, <<"%%VSN%%">>),
    true = rabbit_misc:version_minor_equivalent(<<"3.0.0">>, <<"3.0">>),
    true = rabbit_misc:version_minor_equivalent(<<"3.0.0">>, <<"3.0.0.1">>),
    false = rabbit_misc:version_minor_equivalent(<<"3.0.0">>, <<"3.1.0">>),
    false = rabbit_misc:version_minor_equivalent(<<"3.0.0.1">>, <<"3.1.0.1">>).

version_minor_equivalence_properties(_Config) ->
    true = proper:counterexample(
             ?FORALL(
                {A, B},
                {version(), version()},
                check_minor_equivalent(A, B)
               ),
             [
              quiet,
              {numtests, 10000},
              {on_output, fun(F, A) -> ct:pal(?LOW_IMPORTANCE, F, A) end}
             ]
            ).

version_comparison(_Config) ->
    true = proper:counterexample(
             ?FORALL(
                {A, B},
                {version(), version()},
                check_and_compare_versions(A, B)
               ),
             [
              quiet,
              {numtests, 10000},
              {on_output, fun(F, A) -> ct:pal(?LOW_IMPORTANCE, F, A) end}
             ]
            ).

version() ->
    union([
           [],
           release(),
           prerelease()
          ]).

release() ->
    union([
           identifier(),
           [non_neg_integer()],
           [non_neg_integer(), ".", 0],
           [non_neg_integer(), ".", frequency([{1, 0}, {1, pos_integer()}])],
           [non_neg_integer(), ".", non_neg_integer(), ".", frequency([{1, 0}, {1, pos_integer()}])]
          ]).

prerelease() ->
    {release(), "-", identifier()}.

identifier() ->
    union(
      [[identifier_first_char()],
       non_empty(list(identifier_char()))]
     ).

identifier_first_char() ->
    union([non_zero_digit(), uppercase(), lowercase()]).

%% FIXME: We should have $- as a valid identifier_char(), but the
%% rabbit_semver library doesn't support having a dash as the last
%% character in an identifier. For now, do not use dashes in an
%% identifier. We could probably fix the property to only generate dash
%% as the non-first non-last character.
identifier_char() ->
    union([digit(), uppercase(), lowercase()]).

digit()          -> integer(48, 57).
non_zero_digit() -> integer(49, 57).
uppercase()      -> integer(65, 90).
lowercase()      -> integer(97, 122).

check_minor_equivalent({Release, Sep, Extra}, B) ->
    A = Release ++ [Sep, Extra],
    check_minor_equivalent(A, B);
check_minor_equivalent(A, {Release, Sep, Extra}) ->
    B = Release ++ [Sep, Extra],
    check_minor_equivalent(A, B);

check_minor_equivalent([], []) ->
    check_minor_equivalent([], [], true);
check_minor_equivalent([Maj, ".", 0 | _] = A, [Maj] = B)
  when is_integer(Maj) ->
    check_minor_equivalent(A, B, true);
check_minor_equivalent([Maj, ".", 0 | _] = A, [Maj, "-", _ | _] = B)
  when is_integer(Maj) ->
    check_minor_equivalent(A, B, true);

check_minor_equivalent([Maj] = A, [Maj, ".", 0 | _] = B)
  when is_integer(Maj) ->
    check_minor_equivalent(A, B, true);
check_minor_equivalent([Maj, "-", _ | _] = A, [Maj, ".", 0 | _] = B)
  when is_integer(Maj) ->
    check_minor_equivalent(A, B, true);

check_minor_equivalent([Maj, ".", 0 | _] = A, [Maj, ".", 0 | _] = B)
  when is_integer(Maj) ->
    check_minor_equivalent(A, B, true);

check_minor_equivalent([Maj] = A, [Maj] = B)
  when is_integer(Maj) ->
    check_minor_equivalent(A, B, true);
check_minor_equivalent([Maj, "-", _ | _] = A, [Maj] = B)
  when is_integer(Maj) ->
    check_minor_equivalent(A, B, true);
check_minor_equivalent([Maj] = A, [Maj, "-", _ | _] = B)
  when is_integer(Maj) ->
    check_minor_equivalent(A, B, true);
check_minor_equivalent([Maj, "-", _ | _] = A, [Maj, "-", _ | _] = B)
  when is_integer(Maj) ->
    check_minor_equivalent(A, B, true);

check_minor_equivalent([3, ".", 6, ".", PatchA | _] = A, [3, ".", 6, ".", PatchB | _] = B)
  when is_integer(PatchA) andalso is_integer(PatchB) ->
    Expected = if
                   PatchA >= 6 -> PatchB >= 6;
                   PatchA < 6  -> PatchB < 6;
                   true -> false
               end,
    check_minor_equivalent(A, B, Expected);

check_minor_equivalent([Maj, ".", Min | _] = A, [Maj, ".", Min | _] = B)
  when is_integer(Maj) andalso is_integer(Min) ->
    check_minor_equivalent(A, B, true);

check_minor_equivalent(A, B) ->
    check_minor_equivalent(A, B, false).

check_minor_equivalent(RawA, RawB, Expected) ->
    A = lists:flatten([raw_to_string(Char) || Char <- RawA]),
    B = lists:flatten([raw_to_string(Char) || Char <- RawB]),
    Expected =:= rabbit_misc:version_minor_equivalent(A, B).

check_and_compare_versions({Release, Sep, Extra}, B) ->
    A = Release ++ [Sep, Extra],
    check_and_compare_versions(A, B);
check_and_compare_versions(A, {Release, Sep, Extra}) ->
    B = Release ++ [Sep, Extra],
    check_and_compare_versions(A, B);
check_and_compare_versions(RawA, RawB) ->
    A = lists:flatten([raw_to_string(Char) || Char <- RawA]),
    B = lists:flatten([raw_to_string(Char) || Char <- RawB]),
    Result1 = rabbit_misc:version_compare(A, B),
    Result2 = rabbit_misc:version_compare(B, A),
    case {Result1, Result2} of
        {lt, gt} ->
            true =:= rabbit_misc:version_compare(A, B, lte) andalso
            false =:= rabbit_misc:version_compare(A, B, gte) andalso
            false =:= rabbit_misc:version_compare(A, B, eq);
        {gt, lt} ->
            true =:= rabbit_misc:version_compare(A, B, gte) andalso
            false =:= rabbit_misc:version_compare(A, B, lte) andalso
            false =:= rabbit_misc:version_compare(A, B, eq);
        {eq, eq} ->
            true =:= rabbit_misc:version_compare(A, B, gte) andalso
            true =:= rabbit_misc:version_compare(A, B, lte) andalso
            true =:= rabbit_misc:version_compare(A, B, eq);
        _ ->
            ct:pal(
              "rabbit_misc:version_compare/2 failure:~n"
              "A: ~p~n"
              "B: ~p~n"
              "Result1: ~p~n"
              "Result2: ~p~n", [A, B, Result1, Result2]),
            false
    end.

raw_to_string(Char)
  when is_integer(Char) ->
    integer_to_list(Char);
raw_to_string(Char) ->
    Char.
