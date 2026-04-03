# powershell -Command
Get-FileHash 'C:\Workspace\IWON-vm-lab\backup\dev-was\GodisWebServer-0.0.1-SNAPSHOT.jar' -Algorithm SHA256 | Format-List; Add-Type -AssemblyName System.IO.Compression.FileSystem; $zip=[IO.Compression.ZipFile]::OpenRead('C:\Workspace\IWON-vm-lab\backup\dev-was\GodisWebServer-0.0.1-SNAPSHOT.jar'); $entry=$zip.GetEntry('META-INF/MANIFEST.MF'); $sr=New-Object IO.StreamReader($entry.Open()); $sr.ReadToEnd(); $sr.Close(); $zip.Dispose()

#!/bin/bash
sha256sum /opt/apps/was/app.jar; echo; jar xf /opt/apps/was/app.jar META-INF/MANIFEST.MF && cat META-INF/MANIFEST.MF
# result
#
# Algorithm : SHA256
# Hash      : 7F2A892DAAB954F7783F7D686931D75BF0DBEF23F298338B06E882B22786FDCD
# Path      : C:\Workspace\IWON-vm-lab\backup\dev-was\GodisWebServer-0.0.1-SNAPSHOT.jar

# Manifest-Version: 1.0
# Main-Class: org.springframework.boot.loader.launch.JarLauncher
# Start-Class: com.godisweb.GodisWebApplication
# Spring-Boot-Version: 3.2.6
# Spring-Boot-Classes: BOOT-INF/classes/
# Spring-Boot-Lib: BOOT-INF/lib/
# Spring-Boot-Classpath-Index: BOOT-INF/classpath.idx
# Spring-Boot-Layers-Index: BOOT-INF/layers.idx
# Build-Jdk-Spec: 17
# Implementation-Title: GodisWebServer
# Implementation-Version: 0.0.1-SNAPSHOT

#!/bin/bash
# Check if the JAR file contains any references to the IP address 192.168
strings /opt/apps/was/app.jar | grep -c '192\.168'