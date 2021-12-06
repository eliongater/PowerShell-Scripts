Following instructions from:
https://developers.hp.com/hp-client-management/blog/deploying-hp-client-management-script-library-microsoft-intune

To package/prep for Intune HP Client Mangement Scripts from:
https://ftp.ext.hp.com/pub/caps-softpaq/cmit/hp-cmsl.html

Used for managing HP BIOS' in a simplier fashion than the standard HP BIOS tool


Paraphrased instructions:
..\bin\IntuneWinAppUtil -c .\content\ -s hp-cmsl-latest.exe -o .\output\

  Install:
  hp-cmsl-latest.exe /VERYSILENT /NORESTART /SUPPRESSMSGBOXES
  
  Uninstall:
  C:\Program Files\WindowsPowerShell\HP.CMSL.UninstallerData\unins000.exe /VERYSILENT /NORESTART /SUPPRESSMSGBOXES
  
  Detection:
      Rule type: Registry
      Key path: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{5A1AECCB-E0CE-4D2C-833C-29CCEA959448}_is1
      Value name: DisplayVersion
      Detection method: String comparison
      Operator: Equals
      Value: 1.5.0
      Associated with 32-bit app on 64-bit clients: yes
