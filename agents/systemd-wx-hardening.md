# Per-daemon W^X hardening (systemd units)

Linux has no system-wide W^X (write-xor-execute) knob by design (JITs need
write-then-execute). security-misc's `vm.memfd_noexec=2` is only a bar-raiser,
not W^X. The idiomatic closure is PER-DAEMON, applied to resident daemons that
never JIT, via systemd unit directives. This is the pattern used by kloak,
sdwdate, privleapd, onion-grater, canary and the other resident daemons.

## When NOT to apply (SKIP + flag)

A daemon that legitimately does write-then-execute MUST NOT get this pattern:
browsers (V8/JSC/SpiderMonkey), Java, Mono/.NET, LuaJIT/PyPy, Wine, and CPython
ONLY if it uses ctypes CALLBACKS (`ctypes.CFUNCTYPE`/`PYFUNCTYPE` -> libffi
closures allocate executable trampolines) or the opt-in 3.13 experimental JIT.
Plain CPython + `dlopen` of `.so` libraries is FINE (library maps are PROT_EXEC
without PROT_WRITE). Classify each daemon; TEST, do not assume.

## The pattern

Layer 1 -- anonymous executable memory (apply to every non-JIT daemon):

    MemoryDenyWriteExecute=true      ## deny anon W+X and mprotect/shmat gaining PROT_EXEC
    SystemCallArchitectures=native   ## close the secondary-ABI (i386 ipc/mmap2) bypass of MDWE
    LockPersonality=true             ## block the READ_IMPLIES_EXEC personality bypass
    SystemCallFilter=~memfd_create   ## kill the anon memfd exec-bypass (or: an allow-list that omits memfd_create)

Why all four: `MemoryDenyWriteExecute` on current kernels is `prctl(PR_SET_MDWE,
PR_MDWE_REFUSE_EXEC_GAIN)` (violation errno EACCES; a seccomp EPERM filter is the
pre-6.3 fallback). Alone it leaves three bypasses: a written `memfd` mapped
`PROT_READ|PROT_EXEC` (closed by `~memfd_create`), the i386 secondary ABI
(`SystemCallArchitectures=native`), and `READ_IMPLIES_EXEC` on the seccomp
fallback (`LockPersonality`).

Layer 2 -- file-backed executable mappings (MDWE does NOT cover these: an
already-written file mapped `PROT_READ|PROT_EXEC` has no PROT_WRITE bit):

    ## dropped-privilege daemon, no AppArmor profile:
    NoExecPaths=/run /tmp /var/tmp /dev/shm   ## + the daemon's own writable state dir
    ## a write-nothing daemon can also take, for a near-complete close:
    ProtectSystem=strict
    ProtectHome=yes

For a ROOT daemon also list `/dev` (devtmpfs is rw and NOT noexec, so uid 0 can
drop a file there and execve it) and the daemon's own state dir (e.g.
`/var/lib/<daemon>`); `ProtectSystem=full/strict` does not cover `/dev`, `/var`,
`/opt`, `/srv`. GOTCHA: a `+`-prefixed `ExecStartPre=` or `PermissionsStartOnly=true`
makes that control process run as root EXEMPT from the unit sandbox (no MDWE /
SystemCallFilter / NoExecPaths) -- so W^X covers `ExecStart=` only; do not claim
the ExecStartPre helper is covered.

    ## daemon WITH an AppArmor profile: deny executable mapping (`m`) on every
    ## WRITABLE path -- grant `m` only on read-only trusted paths (its binary +
    ## system libs). e.g. sdwdate: `/tmp/* rw,` not `/tmp/* mrw,`.

Root daemon that spawns privilege-gaining children (an escalator, e.g.
privleapd):

    NoNewPrivileges=false   ## explicit; the MDWE/SystemCallFilter seccomp still
                            ## installs via the root executor's CAP_SYS_ADMIN, and
                            ## stays off so an escalated SUID helper still works.

All of MDWE / SystemCallArchitectures / LockPersonality / SystemCallFilter /
NoExecPaths are a seccomp filter or a mount namespace: they INHERIT across
fork/execve into the daemon's children. For an escalator this is by design (W^X
covers the escalated actions too) but means a 32-bit or READ_IMPLIES_EXEC child
would be refused -- document that caveat in the unit.

## Completeness (be honest in the unit comment)

- DROPPED-PRIVILEGE daemon: COMPLETE W^X. Its writable set is exactly the
  NoExecPaths dirs (ProtectSystem + non-root keep it there), or its AppArmor
  profile denies `m` on all writable paths.
- ROOT daemon: Layer 1 (anonymous) is COMPLETE; Layer 2 (file-backed) is PARTIAL
  -- NoExecPaths closes the common scratch dirs, but uid 0 can still exec a file
  written on another executable filesystem, or clear noexec via `mount_setattr`.
  A COMPLETE file-backed close for a root process needs MAC (a dedicated AppArmor
  profile / LSM), NOT systemd unit settings alone. State this residual in the
  unit comment; do not claim a complete close. For a SIMPLE write-nothing root
  daemon, `ProtectSystem=strict` + `ProtectHome` shrink the residual to near
  nothing; for an arbitrary-action escalator, leave it at Layer 1 + the scratch
  dirs + a documented residual (ProtectSystem would break its actions).

## Verify empirically (do not theorize)

Per daemon: it still reaches active/running and performs its real function with
NO SIGSYS/seccomp denial in the journal (`/proc/<pid>/status` shows `Seccomp: 2`),
AND a probe proves closure -- `mprotect(+PROT_EXEC)` / `mmap(W|X)` -> EACCES,
`memfd_create` -> EPERM/SIGSYS, and a file-backed `mmap(PROT_READ|PROT_EXEC)` in
a NoExecPaths dir -> EACCES/EPERM. An escalator additionally: a real action
escalates+runs under the hardened unit.
