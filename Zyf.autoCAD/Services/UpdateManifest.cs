using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;

namespace ZYF.autoCAD.Services
{
    public class UpdateManifest
    {
        public string AppId { get; set; }
        public string LatestVersion { get; set; }
        public string ReleaseDate { get; set; }
        public string Title { get; set; }
        public List<string> Changelog { get; set; } = new List<string>();
        public string DownloadUrl { get; set; }
        public string Sha256 { get; set; }
        public bool Mandatory { get; set; }
        public string MinimumSupportedVersion { get; set; }
        public string HomepageUrl { get; set; }
        public string ReleaseNotesUrl { get; set; }

        public static UpdateManifest FromDictionary(IDictionary<string, object> values)
        {
            return new UpdateManifest
            {
                AppId = ReadString(values, "appId"),
                LatestVersion = ReadString(values, "latestVersion"),
                ReleaseDate = ReadString(values, "releaseDate"),
                Title = ReadString(values, "title"),
                Changelog = ReadStringList(values, "changelog"),
                DownloadUrl = ReadString(values, "downloadUrl"),
                Sha256 = ReadString(values, "sha256"),
                Mandatory = ReadBool(values, "mandatory"),
                MinimumSupportedVersion = ReadString(values, "minimumSupportedVersion"),
                HomepageUrl = ReadString(values, "homepageUrl"),
                ReleaseNotesUrl = ReadString(values, "releaseNotesUrl")
            };
        }

        private static string ReadString(IDictionary<string, object> values, string key)
        {
            if (!values.TryGetValue(key, out object value) || value == null)
            {
                return string.Empty;
            }

            return Convert.ToString(value, CultureInfo.InvariantCulture) ?? string.Empty;
        }

        private static bool ReadBool(IDictionary<string, object> values, string key)
        {
            if (!values.TryGetValue(key, out object value) || value == null)
            {
                return false;
            }

            if (value is bool boolValue)
            {
                return boolValue;
            }

            return bool.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), out bool parsed) && parsed;
        }

        private static List<string> ReadStringList(IDictionary<string, object> values, string key)
        {
            var result = new List<string>();
            if (!values.TryGetValue(key, out object value) || value == null)
            {
                return result;
            }

            if (value is ArrayList items)
            {
                foreach (object item in items)
                {
                    string text = Convert.ToString(item, CultureInfo.InvariantCulture);
                    if (!string.IsNullOrWhiteSpace(text))
                    {
                        result.Add(text);
                    }
                }
            }

            return result;
        }
    }
}
