using System;
using System.IO;
using System.IO.Compression;
using System.Security.Cryptography;

namespace ZYF.autoCAD.Services
{
    // The full delivery stores mutable data next to its runtime files. Keep that
    // root in the existing per-user CADTools data directory, never Program Files.
    internal static class EmergencyLightingRuntime
    {
        internal const string ArchiveName = "full-v0.1.84.zip";
        internal const string EntryName = "ELFULL84-CADTools.lsp";
        internal const string PackageMarker = "package-183.marker";
        private const string Prefix = "应急照明-v0.1.84/";
        private const string ArchiveSha256 = "a3525a0e73ec174d6f6caba413edf5f54e00ff5a91fe8290287dbf6970ea8931";
        private const string EntrySha256 = "e711bbe08052f586dadb41d04efcff760c8e4f701742e84949267d0a58721035";

        internal static string Prepare(string moduleRoot)
        {
            string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            if (string.IsNullOrWhiteSpace(local))
                throw new IOException("无法确定当前用户的 LocalAppData 目录。");
            return PrepareAt(moduleRoot, Path.Combine(local, "Emergency-Lighting", "CADTools"));
        }

        // Internal path injection permits exercising the real extraction without
        // touching a user's drawing data or installed AutoCAD.
        internal static string PrepareAt(string moduleRoot, string dataRoot)
        {
            string archivePath = Path.Combine(moduleRoot, ArchiveName);
            string entryPath = Path.Combine(moduleRoot, EntryName);
            VerifyHash(archivePath, ArchiveSha256);
            VerifyHash(entryPath, EntrySha256);

            string root = Path.GetFullPath(dataRoot).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                + Path.DirectorySeparatorChar;
            Directory.CreateDirectory(Path.Combine(root, "config"));
            Directory.CreateDirectory(Path.Combine(root, "output"));
            using (ZipArchive archive = ZipFile.OpenRead(archivePath))
            {
                // Commit the marker last so an incomplete extraction is never ready.
                ZipArchiveEntry marker = null;
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    if (!entry.FullName.StartsWith(Prefix, StringComparison.Ordinal))
                        throw new InvalidDataException("应急照明包目录不符合预期。");
                    string name = entry.FullName.Substring(Prefix.Length);
                    if (string.IsNullOrEmpty(name) || name.EndsWith("/", StringComparison.Ordinal)) continue;
                    if (name == PackageMarker) { marker = entry; continue; }
                    if (!IsRuntimeFile(name)) continue;
                    CopyVerified(entry, root, name);
                }
                if (marker == null) throw new InvalidDataException("应急照明包缺少版本标记。");
                CopyVerified(marker, root, PackageMarker);
            }
            return root;
        }

        private static bool IsRuntimeFile(string name)
        {
            return name.StartsWith("src/", StringComparison.Ordinal)
                || name.StartsWith("ui/", StringComparison.Ordinal)
                || name.StartsWith("native/", StringComparison.Ordinal)
                || name.StartsWith("templates/", StringComparison.Ordinal)
                || name.StartsWith("assets/default-device-library/", StringComparison.Ordinal);
        }

        private static void CopyVerified(ZipArchiveEntry entry, string root, string name)
        {
            string relative = name.Replace('/', Path.DirectorySeparatorChar);
            string destination = Path.GetFullPath(Path.Combine(root, relative));
            if (!destination.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("应急照明运行文件路径越界。");
            Directory.CreateDirectory(Path.GetDirectoryName(destination));
            using (Stream input = entry.Open())
            using (var buffer = new MemoryStream())
            {
                input.CopyTo(buffer);
                byte[] expected = buffer.ToArray();
                if (File.Exists(destination))
                {
                    if (!SameBytes(destination, expected))
                        throw new IOException("应急照明运行文件与本版本不一致，已保留原文件：" + destination);
                    return;
                }
                string temporary = destination + "." + Guid.NewGuid().ToString("N") + ".tmp";
                try
                {
                    File.WriteAllBytes(temporary, expected);
                    try { File.Move(temporary, destination); }
                    catch (IOException)
                    {
                        // Another CAD process may have prepared the same package.
                        if (!File.Exists(destination) || !SameBytes(destination, expected)) throw;
                    }
                    if (!SameBytes(destination, expected))
                        throw new IOException("应急照明运行文件回读失败：" + destination);
                }
                finally { if (File.Exists(temporary)) File.Delete(temporary); }
            }
        }

        private static bool SameBytes(string path, byte[] expected)
        {
            byte[] actual = File.ReadAllBytes(path);
            if (actual.Length != expected.Length) return false;
            for (int i = 0; i < actual.Length; i++)
                if (actual[i] != expected[i]) return false;
            return true;
        }

        private static void VerifyHash(string path, string expected)
        {
            if (!File.Exists(path)) throw new FileNotFoundException("应急照明交付文件缺失：" + path, path);
            using (var sha = SHA256.Create())
            using (var stream = File.OpenRead(path))
            {
                string actual = BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "").ToLowerInvariant();
                if (!string.Equals(actual, expected, StringComparison.Ordinal))
                    throw new InvalidDataException("应急照明交付文件校验失败：" + path);
            }
        }
    }
}
