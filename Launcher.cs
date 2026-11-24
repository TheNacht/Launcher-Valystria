using System;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
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
            using (var runspace = RunspaceFactory.CreateRunspace()) {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                using (var shell = PowerShell.Create()) {
                    shell.Runspace = runspace;
                    shell.AddCommand("Set-ExecutionPolicy").AddParameter("Scope", "Process")
                        .AddParameter("ExecutionPolicy", "Bypass").AddParameter("Force").Invoke();
                    shell.Commands.Clear();
                    shell.AddCommand(Path.Combine(root, "Iniciar.ps1")).Invoke();
                    if (shell.HadErrors && shell.Streams.Error.Count > 0)
                        throw new InvalidOperationException(shell.Streams.Error[0].ToString());
                }
            }
        } catch (Exception error) { MessageBox.Show(error.Message, "Valystria Outbreak"); }
    }
}

