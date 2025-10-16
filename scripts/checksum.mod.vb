' FileIntegrityChecker.vb
' Single-file VB.NET console app to create/verify SHA256 manifests for .ps1 (or any) files.
' Targets .NET 6+ or .NET Framework (needs System.Text.Json on older frameworks).
' Usage examples shown at bottom of Main.
' Author: ChatGPT (adapted by me lol, but yes Im not learning vb.net so I vibe coded this)
' Date: 2024-06-27
' License: AFL-3.0

Imports System
Imports System.IO
Imports System.Security.Cryptography
Imports System.Text
Imports System.Text.Json
Imports System.Data
Imports System.Globalization

Module FileIntegrityChecker

    ' Manifest format: Dictionary(Of String, String) -> filepath -> SHA256 hex
    Private ReadOnly ManifestFileExtension As String = ".manifest.json"

    Sub Main()
        ' Example usage:
        ' 1) Create manifest from an array:
        Dim filesArray As String() = {
            "..\modules\http.psm1",
            "..\modules\res32.psm1",
            "..\modules\wp32.psm1",
        }

        ' 2) Create a DataTable to simulate another input form:
        Dim dt As New DataTable("Files")
        dt.Columns.Add("Path", GetType(String))
        dt.Rows.Add("..\modules\http.psm1")
        dt.Rows.Add("..\modules\res32.psm1")
        dt.Rows.Add("..\modules\wp32.psm1")

        ' -------- DEMOS --------
        ' Create a manifest from the array
        Console.WriteLine("Creating manifest from array...")
        Dim manifestPath = CreateManifestFromPaths(filesArray, "C:\scripts\my_scripts" & ManifestFileExtension, overwrite:=True)
        Console.WriteLine("Manifest created at: " & manifestPath)
        Console.WriteLine()

        ' Verify the same files using the manifest
        Console.WriteLine("Verifying files from DataTable against manifest...")
        Dim results = VerifyAgainstManifest(dt, manifestPath, dataTablePathColumnName:="Path")
        PrintResults(results)
        Console.WriteLine()

        ' Example: verify and auto-update manifest where new files are added or changed
        Console.WriteLine("Verifying and auto-updating manifest (if you want) ...")
        Dim autoUpdateResults = VerifyAgainstManifest(filesArray, manifestPath, dataTablePathColumnName:=Nothing, autoUpdateManifest:=True)
        PrintResults(autoUpdateResults)
        Console.WriteLine()

        Console.WriteLine("Done. Press Enter to exit.")
        Console.ReadLine()
    End Sub

    ' ------------------------------
    ' CORE FUNCTIONS
    ' ------------------------------

    ' Compute SHA256 for a file, returns hex string
    Public Function ComputeFileSHA256Hex(filePath As String) As String
        If Not File.Exists(filePath) Then
            Throw New FileNotFoundException("File not found", filePath)
        End If
        Using sha As SHA256 = SHA256.Create()
            Using stream = File.OpenRead(filePath)
                Dim hashBytes = sha.ComputeHash(stream)
                Return BytesToHex(hashBytes)
            End Using
        End Using
    End Function

    Private Function BytesToHex(bytes As Byte()) As String
        Dim sb As New StringBuilder(bytes.Length * 2)
        For Each b In bytes
            sb.AppendFormat("{0:x2}", b)
        Next
        Return sb.ToString()
    End Function

    ' Create or overwrite a manifest given an IEnumerable of file paths
    ' manifestPath: full path to output manifest (should end with .json)
    ' overwrite: if True, overwrite existing
    Public Function CreateManifestFromPaths(paths As IEnumerable(Of String), manifestPath As String, Optional overwrite As Boolean = False) As String
        If File.Exists(manifestPath) AndAlso Not overwrite Then
            Throw New IOException("Manifest already exists. Use overwrite:=True to replace.")
        End If

        Dim dict As New Dictionary(Of String, String)(StringComparer.OrdinalIgnoreCase)
        For Each rawPath In paths
            If String.IsNullOrWhiteSpace(rawPath) Then Continue For
            Dim p = Path.GetFullPath(rawPath)
            If File.Exists(p) Then
                Try
                    dict(p) = ComputeFileSHA256Hex(p)
                Catch ex As Exception
                    Console.WriteLine($"[WARN] Failed to hash {p}: {ex.Message}")
                End Try
            Else
                Console.WriteLine($"[WARN] File missing when creating manifest: {p}")
            End If
        Next

        Dim options = New JsonSerializerOptions With {
            .WriteIndented = True
        }
        Dim json = JsonSerializer.Serialize(dict, options)
        Directory.CreateDirectory(Path.GetDirectoryName(manifestPath))
        File.WriteAllText(manifestPath, json, Encoding.UTF8)
        Return manifestPath
    End Function

    ' Overload: accept a DataTable (column name must be specified)
    Public Function CreateManifestFromDataTable(dt As DataTable, pathColumnName As String, manifestPath As String, Optional overwrite As Boolean = False) As String
        Dim paths As New List(Of String)
        For Each r As DataRow In dt.Rows
            If dt.Columns.Contains(pathColumnName) Then
                Dim val = r(pathColumnName)
                If val IsNot Nothing Then paths.Add(Convert.ToString(val))
            End If
        Next
        Return CreateManifestFromPaths(paths, manifestPath, overwrite)
    End Function

    ' Verify given paths or DataTable against an existing manifest
    ' Returns a list of ResultEntry
    Public Function VerifyAgainstManifest(pathsInput As IEnumerable(Of String), manifestPath As String, Optional dataTablePathColumnName As String = Nothing, Optional autoUpdateManifest As Boolean = False) As List(Of ResultEntry)
        If Not File.Exists(manifestPath) Then Throw New FileNotFoundException("Manifest not found", manifestPath)

        Dim json = File.ReadAllText(manifestPath, Encoding.UTF8)
        Dim manifest = JsonSerializer.Deserialize(Of Dictionary(Of String, String))(json)

        ' Normalize manifest keys
        Dim normalizedManifest As New Dictionary(Of String, String)(StringComparer.OrdinalIgnoreCase)
        For Each kv In manifest
            normalizedManifest(Path.GetFullPath(kv.Key)) = kv.Value
        Next

        Dim results As New List(Of ResultEntry)()
        Dim providedPaths As New HashSet(Of String)(StringComparer.OrdinalIgnoreCase)

        For Each rawPath In pathsInput
            If String.IsNullOrWhiteSpace(rawPath) Then Continue For
            Dim p = Path.GetFullPath(rawPath)
            providedPaths.Add(p)
            If Not File.Exists(p) Then
                results.Add(New ResultEntry With {.Path = p, .Status = IntegrityStatus.Missing, .ExpectedHash = If(normalizedManifest.ContainsKey(p), normalizedManifest(p), Nothing)})
                Continue For
            End If

            Dim currentHash As String = Nothing
            Try
                currentHash = ComputeFileSHA256Hex(p)
            Catch ex As Exception
                results.Add(New ResultEntry With {.Path = p, .Status = IntegrityStatus.Error, .Message = ex.Message})
                Continue For
            End Try

            If normalizedManifest.ContainsKey(p) Then
                Dim expected = normalizedManifest(p)
                If String.Equals(expected, currentHash, StringComparison.OrdinalIgnoreCase) Then
                    results.Add(New ResultEntry With {.Path = p, .Status = IntegrityStatus.Ok, .ExpectedHash = expected, .ActualHash = currentHash})
                Else
                    results.Add(New ResultEntry With {.Path = p, .Status = IntegrityStatus.Modified, .ExpectedHash = expected, .ActualHash = currentHash})
                    If autoUpdateManifest Then
                        normalizedManifest(p) = currentHash
                    End If
                End If
            Else
                results.Add(New ResultEntry With {.Path = p, .Status = IntegrityStatus.New, .ActualHash = currentHash})
                If autoUpdateManifest Then
                    normalizedManifest(p) = currentHash
                End If
            End If
        Next

        ' Check for manifest entries that were not provided in this run (they might be deleted)
        For Each kv In normalizedManifest
            If Not providedPaths.Contains(kv.Key) Then
                If File.Exists(kv.Key) Then
                    ' present on disk but not provided in this run => ignored
                    results.Add(New ResultEntry With {.Path = kv.Key, .Status = IntegrityStatus.Ignored, .ExpectedHash = kv.Value})
                Else
                    ' missing on disk
                    results.Add(New ResultEntry With {.Path = kv.Key, .Status = IntegrityStatus.Missing, .ExpectedHash = kv.Value})
                End If
            End If
        Next

        ' If autoUpdateManifest true, persist updated manifest
        If autoUpdateManifest Then
            Dim options = New JsonSerializerOptions With {.WriteIndented = True}
            Dim toWrite = JsonSerializer.Serialize(normalizedManifest, options)
            File.WriteAllText(manifestPath, toWrite, Encoding.UTF8)
        End If

        Return results.OrderBy(Function(r) r.Path).ToList()
    End Function

    ' Overload: accept DataTable
    Public Function VerifyAgainstManifest(dt As DataTable, manifestPath As String, dataTablePathColumnName As String, Optional autoUpdateManifest As Boolean = False) As List(Of ResultEntry)
        If dt Is Nothing Then Throw New ArgumentNullException(NameOf(dt))
        If String.IsNullOrWhiteSpace(dataTablePathColumnName) Then Throw New ArgumentException("Provide column name containing paths", NameOf(dataTablePathColumnName))

        Dim paths As New List(Of String)
        For Each r As DataRow In dt.Rows
            If dt.Columns.Contains(dataTablePathColumnName) Then
                Dim val = r(dataTablePathColumnName)
                If val IsNot Nothing Then paths.Add(Convert.ToString(val))
            End If
        Next
        Return VerifyAgainstManifest(paths, manifestPath, dataTablePathColumnName, autoUpdateManifest)
    End Function

    ' ------------------------------
    ' REPORTING / HELPERS
    ' ------------------------------
    Private Sub PrintResults(results As List(Of ResultEntry))
        Console.WriteLine("Integrity Check Results (sorted):")
        Console.WriteLine("{0,-10} {1,-8} {2}", "STATUS", "HASH", "FILE")
        For Each r In results
            Dim hashDisplay = If(String.IsNullOrEmpty(r.ActualHash), If(String.IsNullOrEmpty(r.ExpectedHash), "", r.ExpectedHash), r.ActualHash)
            Console.WriteLine($"{r.Status.ToString().PadRight(10)} {ShortenHash(hashDisplay).PadRight(8)} {r.Path}")
            If Not String.IsNullOrEmpty(r.Message) Then
                Console.WriteLine($"    -> {r.Message}")
            End If
        Next
    End Sub

    Private Function ShortenHash(h As String) As String
        If String.IsNullOrEmpty(h) Then Return ""
        If h.Length <= 8 Then Return h
        Return h.Substring(0, 8)
    End Function

    ' Utility to write CSV report of results
    Public Sub WriteCsvReport(results As IEnumerable(Of ResultEntry), outPath As String)
        Using sw As New StreamWriter(outPath, False, Encoding.UTF8)
            sw.WriteLine("Path,Status,ExpectedHash,ActualHash,Message")
            For Each r In results
                Dim line = String.Format("""{0}"",""{1}"",""{2}"",""{3}"",""{4}""",
                                         r.Path.Replace("""", """"""),
                                         r.Status.ToString(),
                                         If(r.ExpectedHash, ""),
                                         If(r.ActualHash, ""),
                                         If(r.Message, ""))
                sw.WriteLine(line)
            Next
        End Using
    End Sub

    ' ------------------------------
    ' DATA MODELS
    ' ------------------------------
    Public Enum IntegrityStatus
        Ok
        Modified
        Missing
        New
        Ignored
        Error
    End Enum

    Public Class ResultEntry
        Public Property Path As String
        Public Property Status As IntegrityStatus
        Public Property ExpectedHash As String
        Public Property ActualHash As String
        Public Property Message As String
    End Class

End Module
