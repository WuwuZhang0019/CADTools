using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Web.Script.Serialization;

namespace ZYF.autoCAD.Services
{
    public class UpdateSettings
    {
        public DateTimeOffset? LastCheckUpdateDate { get; set; }
        public string SkippedVersion { get; set; } = string.Empty;
        public string LastDownloadPath { get; set; } = string.Empty;

        public static string ConfigDirectory =>
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "ZYFTools");

        public static string ConfigPath => Path.Combine(ConfigDirectory, "config.json");

        public static UpdateSettings Load()
        {
            try
            {
                if (!File.Exists(ConfigPath))
                {
                    return new UpdateSettings();
                }

                var serializer = new JavaScriptSerializer();
                var values = serializer.Deserialize<Dictionary<string, object>>(File.ReadAllText(ConfigPath));
                var settings = new UpdateSettings
                {
                    SkippedVersion = ReadString(values, "skippedVersion"),
                    LastDownloadPath = ReadString(values, "lastDownloadPath")
                };

                string dateText = ReadString(values, "lastCheckUpdateDate");
                if (DateTimeOffset.TryParse(dateText, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out DateTimeOffset lastCheck))
                {
                    settings.LastCheckUpdateDate = lastCheck;
                }

                return settings;
            }
            catch
            {
                return new UpdateSettings();
            }
        }

        public void Save()
        {
            Directory.CreateDirectory(ConfigDirectory);

            var values = new Dictionary<string, object>
            {
                ["lastCheckUpdateDate"] = LastCheckUpdateDate?.ToString("o", CultureInfo.InvariantCulture) ?? string.Empty,
                ["skippedVersion"] = SkippedVersion ?? string.Empty,
                ["lastDownloadPath"] = LastDownloadPath ?? string.Empty
            };

            var serializer = new JavaScriptSerializer();
            File.WriteAllText(ConfigPath, serializer.Serialize(values));
        }

        private static string ReadString(IDictionary<string, object> values, string key)
        {
            if (values == null || !values.TryGetValue(key, out object value) || value == null)
            {
                return string.Empty;
            }

            return Convert.ToString(value, CultureInfo.InvariantCulture) ?? string.Empty;
        }
    }
}
