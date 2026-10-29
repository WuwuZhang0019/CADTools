using System.IO;

namespace ZYF.autoCAD.Services
{
    internal static class ToolPaths
    {
        // Resolve every command from the assembly's own version directory.
        internal static string Directory()
        {
            return Path.Combine(Path.GetDirectoryName(typeof(ToolPaths).Assembly.Location), "Tools");
        }

        internal static string LispFile(string fileName)
        {
            return Path.Combine(Directory(), fileName).Replace('\\', '/');
        }
    }
}
