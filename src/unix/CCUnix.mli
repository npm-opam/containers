
(* This file is free software, part of containers. See file "license" for more details. *)

(** {1 High-level Functions on top of Unix}

Some useful functions built on top of Unix.

{b status: unstable}
@since 0.10 *)

type 'a or_error = [`Ok of 'a | `Error of string]
type 'a gen = unit -> 'a option

(** {2 Calling Commands} *)

val escape_str : Buffer.t -> string -> unit
(** Escape a string so it can be a shell argument. *)

(*$T
  CCPrint.sprintf "%a" escape_str "foo" = "foo"
  CCPrint.sprintf "%a" escape_str "foo bar" = "'foo bar'"
  CCPrint.sprintf "%a" escape_str "fo'o b'ar" = "'fo'\\''o b'\\''ar'"
*)

type call_result =
  < stdout:string;
    stderr:string;
    status:Unix.process_status;
    errcode:int; (** Extracted from status *)
  >

val call : ?bufsize:int ->
           ?stdin:[`Gen of string gen | `Str of string] ->
           ?env:string array ->
           ('a, Buffer.t, unit, call_result) format4 ->
           'a
(** [call cmd] wraps the result of [Unix.open_process_full cmd] into an
    object. It reads the full stdout and stderr of the subprocess before
    returning.
    @param stdin if provided, the generator or string is consumed and fed to
      the subprocess input channel, which is then closed.
    @param bufsize buffer size used to read stdout and stderr
    @param env environment to run the command in
*)

(*$T
  (call ~stdin:(`Str "abc") "cat")#stdout = "abc"
  (call "echo %a" escape_str "a'b'c")#stdout = "a'b'c\n"
  (call "echo %s" "a'b'c")#stdout = "abc\n"
*)

type line = string

type async_call_result =
  < stdout:line gen;
    stderr:line gen;
    stdin:line -> unit; (* send a line *)
    close_in:unit; (* close stdin *)
    close_err:unit;
    close_out:unit;
    close_all:unit;  (* close all 3 channels *) (** @since 0.11 *)
    wait:Unix.process_status;  (* block until the process ends *)
    wait_errcode:int; (* block until the process ends, then extract errcode *)
       (** @since 0.11 *)
  >
(** A subprocess for interactive usage (read/write channels line by line)
    @since 0.11 *)

val async_call : ?env:string array ->
                 ('a, Buffer.t, unit, async_call_result) format4 ->
                 'a
(** Spawns a subprocess, like {!call}, but the subprocess's channels are
    line generators and line sinks (for stdin).
    if [p] is [async_call "cmd"], then [p#wait] waits for the subprocess
    to die. Channels can be closed independently.
    @since 0.11 *)

(** {2 Accessors}

@since 0.11 *)

val stdout : < stdout : 'a; .. > -> 'a
val stderr : < stderr : 'a; .. > -> 'a
val status : < status : 'a; .. > -> 'a
val errcode : < errcode : 'a; .. > -> 'a

(** {2 Simple IO} *)

val with_in : ?mode:int -> ?flags:Unix.open_flag list ->
              string -> f:(in_channel -> 'a) -> 'a
(** Open an input file with the given optional flag list, calls the function
    on the input channel. When the function raises or returns, the
    channel is closed.
    @param flags opening flags. [Unix.O_RDONLY] is used in any cases
    @since 0.16 *)

val with_out : ?mode:int -> ?flags:Unix.open_flag list ->
               string -> f:(out_channel -> 'a) -> 'a
(** Same as {!with_in} but for an output channel
    @param flags opening flags (default [[Unix.O_CREAT; Unix.O_TRUNC]])
      [Unix.O_WRONLY] is used in any cases.
    @since 0.16 *)

val with_process_in : string -> f:(in_channel -> 'a) -> 'a
(** Open a subprocess and obtain a handle to its stdout
    @since 0.16 *)

val with_process_out : string -> f:(out_channel -> 'a) -> 'a
(** Open a subprocess and obtain a handle to its stdin
    @since 0.16 *)

(** Handle to a subprocess.
    @since 0.16 *)
type process_full = <
  stdin: out_channel;
  stdout: in_channel;
  stderr: in_channel;
  close: Unix.process_status;
>

val with_process_full : ?env:string array -> string -> f:(process_full -> 'a) -> 'a
(** Open a subprocess and obtain a handle to its channels.
    @param env environment to pass to the subprocess.
    @since 0.16 *)

val with_connection : Unix.sockaddr -> f:(in_channel -> out_channel -> 'a) -> 'a
(** Wrap {!Unix.open_connection} with a handler
    @since 0.16 *)

exception ExitServer

val establish_server : Unix.sockaddr -> f:(in_channel -> out_channel -> _) -> unit
(** Listen on the address and calls the handler in a blocking fashion.
    Using {!Thread} is recommended if handlers might take time.
    The callback should raise {!ExitServer} to stop the loop.
    @since 0.16 *)

(** {2 Infix Functions} *)

module Infix : sig
  val (?|) : ('a, Buffer.t, unit, call_result) format4 -> 'a
  (** Infix version of {!call}
      @since 0.11 *)

  val (?|&) : ('a, Buffer.t, unit, async_call_result) format4 -> 'a
  (** Infix version of {!async_call}
      @since 0.11 *)
end

include module type of Infix
