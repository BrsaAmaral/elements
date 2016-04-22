
open Base

module P = Pervasives

let stdin  = P.stdin
let stdout = P.stdout
let stderr = P.stderr

module In_channel = struct
  type t = in_channel

  (* Based on Janestreet's Core library:
     https://github.com/janestreet/core/blob/master/COPYRIGHT.txt *)
  let input_all self =
    (* We use 65536 because that is the size of OCaml's IO buffers. *)
    let buf_size = 65536 in
    let buf = Bytes.create buf_size in
    let buffer = Buffer.create buf_size in
    let rec loop () =
      let len = input self buf 0 (Bytes.length buf) in
      if len > 0 then begin
        Buffer.add_substring buffer buf 0 len;
        loop ()
      end in
    loop ();
    Buffer.contents buffer

  let fold_lines f init self =
    let rec loop r =
      match guard P.input_line self with
      | Some a -> loop (f r a)
      | None   -> r in
    loop init
end

module Labels = struct
  module In_channel = struct
    type t = In_channel.t
    let input_all = In_channel.input_all
    let fold_lines ~f ~init self = In_channel.fold_lines f init self
  end
end

