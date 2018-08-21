module P = Pervasives

let open_in ?(binary=true) p =
  let fn = Path.to_string p in
  if binary then P.open_in_bin fn else P.open_in fn

let open_out ?(binary=true) p =
  let fn = Path.to_string p in
  if binary then P.open_out_bin fn else P.open_out fn

let close_in  = close_in
let close_out = close_out

let with_file_in ?binary fn ~f =
  Exn.protectx (open_in ?binary fn) ~finally:close_in ~f

let with_file_out ?binary p ~f =
  Exn.protectx (open_out ?binary p) ~finally:close_out ~f

let with_lexbuf_from_file fn ~f =
  with_file_in fn ~f:(fun ic ->
    let lb = Lexing.from_channel ic in
    lb.lex_curr_p <-
      { pos_fname = Path.to_string fn
      ; pos_lnum  = 1
      ; pos_bol   = 0
      ; pos_cnum  = 0
      };
    f lb)

let input_lines =
  let rec loop ic acc =
    match input_line ic with
    | exception End_of_file -> List.rev acc
    | line ->
       loop ic (line :: acc)
  in
  fun ic -> loop ic []

let read_all ic =
  let len = in_channel_length ic in
  really_input_string ic len

let read_file ?binary fn = with_file_in fn ~f:read_all ?binary

let lines_of_file fn = with_file_in fn ~f:input_lines ~binary:false

let write_file ?binary fn data =
  with_file_out ?binary fn ~f:(fun oc -> output_string oc data)

let write_lines fn lines =
  with_file_out fn ~f:(fun oc ->
    List.iter ~f:(fun line ->
      output_string oc line;
      output_string oc "\n"
    ) lines
  )

let copy_channels =
  let buf_len = 65536 in
  let buf = Bytes.create buf_len in
  let rec loop ic oc =
    match input ic buf 0 buf_len with
    | 0 -> ()
    | n -> output oc buf 0 n; loop ic oc
  in
  loop

let copy_file ?(chmod=fun x -> x) ~src ~dst () =
  with_file_in src ~f:(fun ic ->
    let perm = (Unix.fstat (Unix.descr_of_in_channel ic)).st_perm |> chmod in
    Exn.protectx (P.open_out_gen
                    [Open_wronly; Open_creat; Open_trunc; Open_binary]
                    perm
                    (Path.to_string dst))
      ~finally:close_out
      ~f:(fun oc ->
        copy_channels ic oc))

let compare_files fn1 fn2 =
  let s1 = read_file fn1 in
  let s2 = read_file fn2 in
  String.compare s1 s2

let read_file_and_normalize_eols fn =
  if not Sys.win32 then
    read_file fn
  else begin
    let src = read_file fn in
    let len = String.length src in
    let dst = Bytes.create len in
    let rec find_next_crnl i =
      match String.index_from src i '\r' with
      | exception Not_found -> None
      | j ->
        if j + 1 < len && src.[j + 1] = '\n' then
          Some j
        else
          find_next_crnl (j + 1)
    in
    let rec loop src_pos dst_pos =
      match find_next_crnl src_pos with
      | None ->
        let len =
          if len > src_pos && src.[len - 1] = '\r' then
            len - 1 - src_pos
          else
            len - src_pos
        in
        Bytes.blit_string src src_pos dst dst_pos len;
        Bytes.sub_string dst 0 (dst_pos + len)
      | Some i ->
        let len = i - src_pos in
        Bytes.blit_string src src_pos dst dst_pos len;
        let dst_pos = dst_pos + len in
        Bytes.set dst dst_pos '\n';
        loop (i + 2) (dst_pos + 1)
    in
    loop 0 0
  end

let compare_text_files fn1 fn2 =
  let s1 = read_file_and_normalize_eols fn1 in
  let s2 = read_file_and_normalize_eols fn2 in
  String.compare s1 s2

module Dsexp = struct
  let load ?lexer path ~mode =
    with_lexbuf_from_file path ~f:(Usexp.Parser.parse ~mode ?lexer)
end
