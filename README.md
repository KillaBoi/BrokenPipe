# BrokenPipe - Steam Client Service LPE Vulnerability

![BrokenPipe launching an interactive NT AUTHORITY SYSTEM command prompt](assets/brokenpipe-system-shell.png)


<i>Greetz to</i> [@MSNIGHTMARE2000](https://github.com/msnightmare) <i>for the inspo - <ins>Please give him a job and email him!</ins></i>
<br>
<i>Shoutout to</i> __Tookie__, __Hazetick__, __belogen__ and __bet3rd__ <i>for being the ultimate homies.</i>
<br>
<i>And you still owe me an Overwatch or Starlight Princess gaming session</i> __lusilly__, meow :3
<br>
</i>

# What is BrokenPipe?

BrokenPipe demonstrates a local privilege escalation from a standard Windows account to
`NT AUTHORITY\SYSTEM` through the Steam Client Service. The proof launches an interactive SYSTEM
command prompt without requesting administrator credentials or displaying a UAC prompt.

## What the screenshot above proves

- BrokenPipe was launched by a standard Windows user.
- Steam was open at its unauthenticated login screen.
- The resulting command prompt ran as `NT AUTHORITY\SYSTEM`.
- `whoami /user` returned the Local System SID, `S-1-5-18`.
- No game was launched.



## Technical summary

The Steam Client Service accepts a caller-controlled installation root that is not covered by the
signature of a genuine Valve-signed install-script VDF. BrokenPipe uses this signature-coverage gap
to make the privileged service execute the included launcher from a relocated path as SYSTEM. It
does not forge, modify, or bypass the VDF signature.

The proof was validated against the current version of Steam `10.96.30.42` on the latest versions of Windows 10 and Windows 11 x64.

## Build

Requirements:

- Visual Studio 2022
- Desktop development with C++ workload
- MSVC v143
- Windows 10 or Windows 11 SDK

Open PowerShell in the project directory and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

The finished executable is written to:

```text
x64\Release\BrokenPipe.exe
```

The build script finds MSBuild, verifies the embedded payload hash, rebuilds the x64 Release
configuration, and prints the final executable path and SHA-256.

You can also open `BrokenPipe.sln` in Visual Studio, select `Release | x64`, and choose
**Build > Rebuild Solution**.

## Usage

1. Sign in as a standard Windows user.
2. Start Steam and leave it idle. A Steam account login is not required.
3. Do not open a game.
4. Run `BrokenPipe.exe` normally, without elevation.
5. Verify the new SYSTEM prompt with `whoami` or `whoami /user` or whatever other command you want to run.
6. Type `exit` or close the SYSTEM prompt when finished.

No command-line arguments or external runtime files are required. The payload ZIP is compiled into
the executable. The proof creates no persistence, launches only the canonical
`C:\Windows\System32\cmd.exe`, and places the elevated process tree in a kill-on-close Windows job.
JSON receipts are written to `C:\Users\Public\BrokenPipe`.

If you want to make adjustments to the payload used, it is located in the payloads folder with the name `BrokenPipePayload.zip`

## Source layout

```text
BrokenPipe\
  assets\
    brokenpipe-system-shell.png
  payload\
    BrokenPipePayload.zip
  BrokenPipe-Bootstrap.ps1
  BrokenPipe.cpp
  BrokenPipe.rc
  BrokenPipe.sln
  BrokenPipe.vcxproj
  build.ps1
  resource.h
  README.md
```

The embedded payload must remain at `payload\BrokenPipePayload.zip` unless its resource path is also
updated in `BrokenPipe.rc`.

## Disclaimer

This project is provided for authorized security research and defensive validation. Test only on
systems you own or have explicit permission to assess.
