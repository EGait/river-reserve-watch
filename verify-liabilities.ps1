# Verifies River's Proof of Liabilities file (a Merkle sum tree).
# Checks every parent node: value = left + right, and hash = SHA256(left_hash | left_value | right_hash | right_value),
# with values as 8-byte little-endian, matching River's open-source proof-of-reserves code.
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\verify-liabilities.ps1 -Path .\river_liabilities\river_liabilities.csv

param(
  [string]$Path = ".\river_liabilities\river_liabilities.csv",
  [decimal]$PublishedBtc = 33498.71382005
)

$code = @"
using System;
using System.IO;
using System.Collections.Generic;
using System.Security.Cryptography;

public static class PorVerify
{
    static byte[] Hex(string s)
    {
        byte[] b = new byte[s.Length / 2];
        for (int i = 0; i < b.Length; i++)
            b[i] = (byte)((HexVal(s[i * 2]) << 4) | HexVal(s[i * 2 + 1]));
        return b;
    }

    static int HexVal(char c)
    {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        throw new FormatException("Bad hex character: " + c);
    }

    static void WriteLE(byte[] buf, int offset, ulong v)
    {
        for (int i = 0; i < 8; i++) { buf[offset + i] = (byte)(v & 0xFF); v >>= 8; }
    }

    static bool Same(byte[] a, byte[] b)
    {
        if (a.Length != b.Length) return false;
        for (int i = 0; i < a.Length; i++) if (a[i] != b[i]) return false;
        return true;
    }

    public static string[] Run(string path)
    {
        List<byte[]> hashes = new List<byte[]>();
        List<ulong> vals = new List<ulong>();
        string header = "";

        foreach (string raw in File.ReadLines(path))
        {
            string line = raw.Trim();
            if (line.Length == 0) continue;
            if (line.StartsWith("block_height")) { header = line; continue; }
            int c = line.IndexOf(',');
            hashes.Add(Hex(line.Substring(0, c)));
            vals.Add(ulong.Parse(line.Substring(c + 1).Trim()));
        }

        int n = hashes.Count;
        long leaves = ((long)n + 1) / 2;
        bool complete = leaves > 0 && (leaves & (leaves - 1)) == 0;

        long badSum = 0, badHash = 0, checkedParents = 0;
        SHA256 sha = SHA256.Create();
        byte[] buf = new byte[80];

        for (long i = 0; 2 * i + 2 < n; i++)
        {
            int l = (int)(2 * i + 1), r = (int)(2 * i + 2), p = (int)i;
            if (vals[l] + vals[r] != vals[p]) badSum++;
            Buffer.BlockCopy(hashes[l], 0, buf, 0, 32);
            WriteLE(buf, 32, vals[l]);
            Buffer.BlockCopy(hashes[r], 0, buf, 40, 32);
            WriteLE(buf, 72, vals[r]);
            if (!Same(sha.ComputeHash(buf), hashes[p])) badHash++;
            checkedParents++;
        }

        ulong leafSum = 0;
        for (long i = n - leaves; i < n; i++) leafSum += vals[(int)i];

        return new string[] {
            header,
            n.ToString(),
            leaves.ToString(),
            complete.ToString(),
            checkedParents.ToString(),
            badSum.ToString(),
            badHash.ToString(),
            vals[0].ToString(),
            leafSum.ToString()
        };
    }
}
"@

Add-Type -TypeDefinition $code -Language CSharp

$full = (Resolve-Path $Path).Path
Write-Host "Reading $full ... (this can take a minute)"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$r = [PorVerify]::Run($full)
$sw.Stop()

$rootSats = [decimal]$r[7]
$leafSats = [decimal]$r[8]
$publishedSats = $PublishedBtc * 100000000

Write-Host ""
Write-Host "River Proof of Liabilities check"
Write-Host "--------------------------------"
Write-Host ("Snapshot                  {0}" -f $r[0])
Write-Host ("Nodes in file             {0:N0}" -f [long]$r[1])
Write-Host ("Leaves                    {0:N0}" -f [long]$r[2])
Write-Host ("Complete tree             {0}" -f $r[3])
Write-Host ("Parent nodes checked      {0:N0}" -f [long]$r[4])
Write-Host ("Sum mismatches            {0}" -f $r[5])
Write-Host ("Hash mismatches           {0}" -f $r[6])
Write-Host ("Root total                {0:N8} BTC" -f ($rootSats / 100000000))
Write-Host ("Sum of all leaves         {0:N8} BTC" -f ($leafSats / 100000000))
Write-Host ("Published liabilities     {0:N8} BTC" -f $PublishedBtc)
Write-Host ""

$ok = ($r[3] -eq "True") -and ($r[5] -eq "0") -and ($r[6] -eq "0") -and ($rootSats -eq $leafSats) -and ($rootSats -eq $publishedSats)
if ($ok) {
  Write-Host "VERIFIED: every node's hash and sum checks out, and the total matches River's published liabilities." -ForegroundColor Green
} else {
  Write-Host "NOT VERIFIED: see the lines above for what didn't match. Check the file path and published figure before drawing conclusions." -ForegroundColor Yellow
}
Write-Host ("Took {0:N1} seconds" -f $sw.Elapsed.TotalSeconds)
