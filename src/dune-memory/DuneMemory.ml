open Stdune
open Utils

type memory = {root: Path.t; log: Log.t}

type promotion =
  | Already_promoted of Path.t * Path.t
  | Promoted of Path.t * Path.t
  | Hash_mismatch of Path.t * Digest.t * Digest.t

let promotion_to_string = function
  | Already_promoted (original, promoted) ->
      Printf.sprintf "%s already promoted as %s" (Path.to_string original)
        (Path.to_string promoted)
  | Promoted (original, promoted) ->
      Printf.sprintf "%s promoted as %s" (Path.to_string original)
        (Path.to_string promoted)
  | Hash_mismatch (original, expected, effective) ->
      Printf.sprintf "hash for %s mismatch: expected %s got %s"
        (Path.to_string original)
        (Digest.to_string expected)
        (Digest.to_string effective)

exception Failed = Utils.Failed

let concat p f = Path.of_string (Filename.concat (Path.to_string p) f)

let path_files memory = concat memory.root "files"

let path_meta memory = concat memory.root "meta"

let path_tmp memory = concat memory.root "temp"

let make ?log root =
  let root = concat root "v2" in
  {root; log= (match log with Some log -> log | None -> Log.no_log)}

(* How to handle collisions. E.g. another version could assume collisions are not possible *)
module Collision = struct
  type res = Found of Path.t | Not_found of Path.t

  (* We need to ensure we do not create holes in the suffix numbering for this to work *)
  let search path file =
    let rec loop n =
      let path = Path.extend_basename path ~suffix:("." ^ string_of_int n) in
      if Sys.file_exists (Path.to_string path) then
        if Io.compare_files path file == Ordering.Eq then Found path
        else loop (n + 1)
      else Not_found path
    in
    loop 1
end

(* Where to store file with a given hash. In this case ab/abcdef. *)
module FSScheme = struct
  let path root hash =
    let hash = Digest.to_string hash in
    let short_hash = String.sub hash ~pos:0 ~len:2 in
    List.fold_left ~f:concat ~init:root [short_hash; hash]
end

let search memory hash file =
  Collision.search (FSScheme.path (path_files memory) hash) file

let promote memory paths metadata _ =
  let promote (path, expected_hash) =
    Log.infof memory.log "promote %s" (Path.to_string path) ;
    let hardlink path =
      let tmp = path_tmp memory in
      (* dune-memory uses a single writer model, the promoted file name can be constant *)
      let dest = concat tmp "promoting" in
      (let dest = Path.to_string dest in
       if Sys.file_exists dest then Unix.unlink dest else mkpath tmp ;
       Unix.link (Path.to_string path) dest) ;
      dest
    in
    let tmp = hardlink path in
    let effective_hash = Digest.file tmp in
    if Digest.compare effective_hash expected_hash != Ordering.Eq then (
      Log.infof memory.log "hash mismatch: %s != %s"
        (Digest.to_string effective_hash)
        (Digest.to_string expected_hash) ;
      Hash_mismatch (path, expected_hash, effective_hash) )
    else
      match search memory effective_hash tmp with
      | Collision.Found p ->
          Unix.unlink (Path.to_string tmp) ;
          Already_promoted (path, p)
      | Collision.Not_found p ->
          mkpath (Path.parent_exn p) ;
          let dest = Path.to_string p in
          Unix.rename (Path.to_string tmp) dest ;
          (* Remove write permissions *)
          Unix.chmod dest ((Unix.stat dest).st_perm land 0o555) ;
          Promoted (path, p)
  in
  unix (fun () ->
      let res = List.map ~f:promote paths
      and metadata_path =
        FSScheme.path (path_meta memory)
          (Digest.string (Csexp.to_string_canonical metadata))
      in
      mkpath (Path.parent_exn metadata_path) ;
      Io.write_file metadata_path
        (Csexp.to_string_canonical
           (Sexp.List
              [ Sexp.List [Sexp.Atom "metadata"; metadata]
              ; Sexp.List
                  [ Sexp.Atom "produced-files"
                  ; Sexp.List
                      (List.filter_map
                         ~f:(function
                           | Promoted (o, p) | Already_promoted (o, p) ->
                               Some
                                 (Sexp.List
                                    [ Sexp.Atom (Path.to_string o)
                                    ; Sexp.Atom (Path.to_string p) ])
                           | _ ->
                               None )
                         res) ] ])) ;
      res )

let search memory metadata =
  let metadata_bin = Csexp.to_string_canonical metadata in
  let hash = Digest.string metadata_bin in
  let path = FSScheme.path (path_meta memory) hash in
  let metadata =
    Io.with_file_in path ~f:(fun input -> Csexp.parse_channel_canonical input)
  in
  match metadata with
  | Sexp.List
      [ Sexp.List [Sexp.Atom s_metadata; _]
      ; Sexp.List [Sexp.Atom s_produced; Sexp.List produced] ] ->
      if
        (not (String.equal s_metadata "metadata"))
        && String.equal s_produced "produced-files"
      then raise (Failed "invalid metadata scheme: wrong key")
      else
        List.map produced ~f:(function
          | Sexp.List [Sexp.Atom f; Sexp.Atom t] ->
              (Path.of_string f, Path.of_string t)
          | _ ->
              raise (Failed "invalid metadata scheme in produced files list") )
  | _ ->
      raise (Failed "invalid metadata scheme")
