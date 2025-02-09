  $ . ../helpers.sh

Here we test the translation and implementation of opam package variables.

We echo each package variable. 

  $ mkrepo
  > mkpkg "testpkg" <<'EOF' 
  > depends: [ "foo" ]
  > build: [
  >   [ "echo" "1"     name ]
  >   [ "echo" "2"   _:name ]
  >   [ "echo" "3" foo:name ]
  >   [ "echo" "4"     version ]
  >   [ "echo" "5"   _:version ]
  >   [ "echo" "6" foo:version ]
  >   [ "echo" "9"    _:installed ]
  >   [ "echo" "10" foo:installed ]
  >   [ "echo" "11"   _:enable ]
  >   [ "echo" "12" foo:enable ]
  >   [ "echo" "13"   _:pinned ]
  >   [ "echo" "14" foo:pinned ]
  >   [ "echo" "15"   _:bin ]
  >   [ "echo" "16" foo:bin ]
  >   [ "echo" "17"   _:sbin ]
  >   [ "echo" "18" foo:sbin ]
  >   [ "echo" "19"   _:lib ]
  >   [ "echo" "20" foo:lib ]
  >   [ "echo" "21"   _:man ]
  >   [ "echo" "22" foo:man ]
  >   [ "echo" "23"   _:doc ]
  >   [ "echo" "24" foo:doc ]
  >   [ "echo" "25"   _:share ]
  >   [ "echo" "26" foo:share ]
  >   [ "echo" "27"   _:etc ]
  >   [ "echo" "28" foo:etc ]
  >   [ "echo" "31"   _:dev ]
  >   [ "echo" "32" foo:dev ]
  >   [ "echo" "35"     with-test ]
  >   [ "echo" "36"   _:with-test ]
  >   [ "echo" "37" foo:with-test ]
  >   [ "echo" "38"     with-doc ]
  >   [ "echo" "39"   _:with-doc ]
  >   [ "echo" "40" foo:with-doc ]
  >   [ "echo" "41"   _:with-dev-setup ]
  >   [ "echo" "42" foo:with-dev-setup ]
  > ]
  > EOF
  > mkpkg "foo" <<EOF
  > EOF
  > solve testpkg
  Solution for dune.lock:
  foo.0.0.1
  testpkg.0.0.1
  
Inspecting the lockfile we can see how each opam package variable was translated into a
corresponding Dune version.

  $ cat dune.lock/testpkg.pkg
  (version 0.0.1)
  
  (build
   (progn
    (run echo 1 %{pkg-self:name})
    (run echo 2 %{pkg-self:name})
    (run echo 3 %{pkg:foo:name})
    (run echo 4 %{pkg-self:version})
    (run echo 5 %{pkg-self:version})
    (run echo 6 %{pkg:foo:version})
    (run echo 9 %{pkg-self:installed})
    (run echo 10 %{pkg:foo:installed})
    (run echo 11 %{pkg-self:enable})
    (run echo 12 %{pkg:foo:enable})
    (run echo 13 %{pkg-self:pinned})
    (run echo 14 %{pkg:foo:pinned})
    (run echo 15 %{pkg-self:bin})
    (run echo 16 %{pkg:foo:bin})
    (run echo 17 %{pkg-self:sbin})
    (run echo 18 %{pkg:foo:sbin})
    (run echo 19 %{pkg-self:lib})
    (run echo 20 %{pkg:foo:lib})
    (run echo 21 %{pkg-self:man})
    (run echo 22 %{pkg:foo:man})
    (run echo 23 %{pkg-self:doc})
    (run echo 24 %{pkg:foo:doc})
    (run echo 25 %{pkg-self:share})
    (run echo 26 %{pkg:foo:share})
    (run echo 27 %{pkg-self:etc})
    (run echo 28 %{pkg:foo:etc})
    (run echo 31 %{pkg-self:dev})
    (run echo 32 %{pkg:foo:dev})
    (run echo 35 %{pkg-self:with-test})
    (run echo 36 %{pkg-self:with-test})
    (run echo 37 %{pkg:foo:with-test})
    (run echo 38 %{pkg-self:with-doc})
    (run echo 39 %{pkg-self:with-doc})
    (run echo 40 %{pkg:foo:with-doc})
    (run echo 41 %{pkg-self:with-dev-setup})
    (run echo 42 %{pkg:foo:with-dev-setup})))
  
  (deps foo)

The values here are not important, but Dune should be able to interpret the variables.

  $ build_pkg testpkg
  File "dune.lock/testpkg.pkg", line 33, characters 15-36:
  33 |   (run echo 35 %{pkg-self:with-test})
                      ^^^^^^^^^^^^^^^^^^^^^
  Error: invalid section "with-test"
  File "dune.lock/testpkg.pkg", line 34, characters 15-36:
  34 |   (run echo 36 %{pkg-self:with-test})
                      ^^^^^^^^^^^^^^^^^^^^^
  Error: invalid section "with-test"
  File "dune.lock/testpkg.pkg", line 35, characters 15-35:
  35 |   (run echo 37 %{pkg:foo:with-test})
                      ^^^^^^^^^^^^^^^^^^^^
  Error: invalid section "with-test"
  File "dune.lock/testpkg.pkg", line 36, characters 15-35:
  36 |   (run echo 38 %{pkg-self:with-doc})
                      ^^^^^^^^^^^^^^^^^^^^
  Error: invalid section "with-doc"
  File "dune.lock/testpkg.pkg", line 37, characters 15-35:
  37 |   (run echo 39 %{pkg-self:with-doc})
                      ^^^^^^^^^^^^^^^^^^^^
  Error: invalid section "with-doc"
  File "dune.lock/testpkg.pkg", line 38, characters 15-34:
  38 |   (run echo 40 %{pkg:foo:with-doc})
                      ^^^^^^^^^^^^^^^^^^^
  Error: invalid section "with-doc"
  File "dune.lock/testpkg.pkg", line 39, characters 15-41:
  39 |   (run echo 41 %{pkg-self:with-dev-setup})
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: invalid section "with-dev-setup"
  File "dune.lock/testpkg.pkg", line 40, characters 15-40:
  40 |   (run echo 42 %{pkg:foo:with-dev-setup})))
                      ^^^^^^^^^^^^^^^^^^^^^^^^^
  Error: invalid section "with-dev-setup"
  [1]
