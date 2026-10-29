using Microsoft.Win32;
using Microsoft.Win32.SafeHandles;
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace ZYF.autoCAD.Services
{
    // 日期：2026-10-20。两个卸载入口共用真实安装路径，不通过待删除的目录联接启动。
    public static class UninstallService
    {
        private const string UninstallKey =
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{D33FF8C5-66B0-4F5C-A4C0-1094E75BE7A5}_is1";

        public static bool LaunchUninstaller(IWin32Window owner = null)
        {
            try
            {
                string assemblyPath = ResolveFilePath(typeof(UninstallService).Assembly.Location);
                string bundlePath = Directory.GetParent(Path.GetDirectoryName(assemblyPath)).FullName;
                if (!string.Equals(Path.GetFileName(bundlePath), "ZYF.bundle", StringComparison.OrdinalIgnoreCase))
                    throw new FileNotFoundException("当前插件未从安装目录加载。请先使用安装包完成安装。");

                string uninstallPath = FindUninstaller(bundlePath);
                using (Process process = Process.Start(new ProcessStartInfo
                {
                    FileName = uninstallPath,
                    WorkingDirectory = bundlePath,
                    UseShellExecute = true,
                    Verb = "runas"
                }))
                {
                    if (process == null) throw new InvalidOperationException("系统未能启动卸载程序。");
                }
                return true;
            }
            catch (Win32Exception ex) when (ex.NativeErrorCode == 1223)
            {
                // 用户取消 UAC 时不关闭关于窗口，也不结束字体辅助程序。
                return false;
            }
            catch (Exception ex)
            {
                MessageBox.Show(owner, $"启动卸载程序失败：{ex.Message}\r\n\r\n" +
                    "如果卸载记录丢失或损坏，请保存图纸并关闭 AutoCAD，使用卸载修复安装包覆盖安装到原目录后再卸载。",
                    "卸载软件", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return false;
            }
        }

        internal static string FindUninstaller(string bundlePath)
        {
            // 修复安装可能生成 unins001.exe 等新编号，以本应用的注册记录为准。
            foreach (RegistryHive hive in new[] { RegistryHive.LocalMachine, RegistryHive.CurrentUser })
            {
                foreach (RegistryView view in new[] { RegistryView.Registry32, RegistryView.Registry64 })
                {
                    try
                    {
                        using (RegistryKey root = RegistryKey.OpenBaseKey(hive, view))
                        using (RegistryKey key = root.OpenSubKey(UninstallKey))
                        {
                            string command = key?.GetValue("UninstallString") as string;
                            if (string.IsNullOrWhiteSpace(command)) continue;
                            string candidate = command.Trim().Trim('"');
                            if (!File.Exists(candidate)) continue;
                            candidate = ResolveFilePath(candidate);
                            if (string.Equals(Path.GetDirectoryName(candidate), bundlePath, StringComparison.OrdinalIgnoreCase)
                                && HasUninstallData(candidate))
                                return candidate;
                        }
                    }
                    catch (System.Security.SecurityException) { }
                    catch (UnauthorizedAccessException) { }
                    catch (IOException) { }
                }
            }

            // 注册信息缺失时只查当前插件所在的安装目录，不卸载其他位置的副本。
            string fallback = new DirectoryInfo(bundlePath).GetFiles("unins???.exe")
                .OrderByDescending(file => file.LastWriteTimeUtc)
                .Where(file => HasUninstallData(file.FullName))
                .Select(file => file.FullName).FirstOrDefault();
            if (fallback == null) throw new FileNotFoundException("找不到完整的卸载程序和卸载记录。");
            return fallback;
        }

        private static bool HasUninstallData(string executable)
        {
            var data = new FileInfo(Path.ChangeExtension(executable, ".dat"));
            return data.Exists && data.Length > 0;
        }

        internal static string ResolveFilePath(string filePath)
        {
            using (var stream = new FileStream(filePath, FileMode.Open, FileAccess.Read,
                FileShare.ReadWrite | FileShare.Delete))
            {
                var buffer = new StringBuilder(512);
                uint length = GetFinalPathNameByHandle(stream.SafeFileHandle, buffer, (uint)buffer.Capacity, 0);
                if (length == 0) throw new Win32Exception(Marshal.GetLastWin32Error());
                if (length >= buffer.Capacity)
                {
                    buffer.Capacity = checked((int)length + 1);
                    length = GetFinalPathNameByHandle(stream.SafeFileHandle, buffer, (uint)buffer.Capacity, 0);
                    if (length == 0 || length >= buffer.Capacity)
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                }

                string path = buffer.ToString();
                if (path.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase))
                    return @"\\" + path.Substring(8);
                return path.StartsWith(@"\\?\", StringComparison.Ordinal) ? path.Substring(4) : path;
            }
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetFinalPathNameByHandle(SafeFileHandle file, StringBuilder path,
            uint pathLength, uint flags);
    }
}
