using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

internal static class Launcher {
    [STAThread]
    static void Main() {
        try {
            var assembly = Assembly.GetExecutingAssembly();
            var root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ValystriaOutbreak", "programa", assembly.ManifestModule.ModuleVersionId.ToString());
            Directory.CreateDirectory(root);
            foreach (string file in assembly.GetManifestResourceNames()) {
                var target = Path.Combine(root, file);
                if (File.Exists(target)) continue;
                var temp = target + "." + Guid.NewGuid();
                try {
                    using (var input = assembly.GetManifestResourceStream(file))
                    using (var output = File.Create(temp)) input.CopyTo(output);
                    try { File.Move(temp, target); }
                    catch (IOException) { if (!File.Exists(target)) throw; }
                } finally { File.Delete(temp); }
            }
            var shell = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
            Process.Start(new ProcessStartInfo(shell, "-NoProfile -STA -ExecutionPolicy Bypass -File \"" +
                Path.Combine(root, "Iniciar.ps1") + "\"") { UseShellExecute = false, CreateNoWindow = true });
        } catch (Exception error) { MessageBox.Show(error.Message, "Valystria Outbreak"); }
    }
}
