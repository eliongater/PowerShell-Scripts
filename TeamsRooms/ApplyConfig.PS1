#See https://docs.microsoft.com/en-us/microsoftteams/rooms/xml-config-file
#and also see https://blog.chiffers.com/2020/11/16/managing-a-microsoft-teams-room-mtr-device-with-intune-part-1-theme/

$BackgroundFile = "C:\Users\Skype\AppData\Local\Packages\Microsoft.SkypeRoomSystem_8wekyb3d8bbwe\LocalState\mtr-wallpaper.jpg"
$ConfigFile = "C:\Users\Skype\AppData\Local\Packages\Microsoft.SkypeRoomSystem_8wekyb3d8bbwe\LocalState\SkypeSettings.xml"

#Background image must be exactly 3840x1080 and a JPG, PNG or BMP, JPG reccomended
$BackgroundImage = "https://www.example.com/resources/img/background.jpg"
$Config = '<SkypeSettings>
<AutoScreenShare>1</AutoScreenShare>
<HideMeetingName>1</HideMeetingName>
<AutoExitMeetingEnabled>true</AutoExitMeetingEnabled>
<AudioRenderDefaultDeviceVolume>70</AudioRenderDefaultDeviceVolume>
<AudioRenderCommunicationDeviceVolume>30</AudioRenderCommunicationDeviceVolume>
<UserAccount>
  <SkypeSignInAddress>username@microsoft.com</SkypeSignInAddress>
  <ExchangeAddress>username@microsoft.com</ExchangeAddress>
  <DomainUsername>domain\username</DomainUsername>
  <Password>Password!</Password>
  <ConfigureDomain>domain1, domain2</ConfigureDomain>
  <ModernAuthEnabled>true</ModernAuthEnabled>
</UserAccount>
<TeamsMeetingsEnabled>true</TeamsMeetingsEnabled>
<SfbMeetingEnabled>true</SfbMeetingEnabled>
<IsTeamsDefaultClient>true</IsTeamsDefaultClient>
<WebExMeetingsEnabled>true</WebExMeetingsEnabled>
<ZoomMeetingsEnabled>true</ZoomMeetingsEnabled>
<UseCustomInfoForThirdPartyMeetings>true</UseCustomInfoForThirdPartyMeetings>
<CustomDisplayNameForThirdPartyMeetings>guestname</CustomDisplayNameForThirdPartyMeetings>
<CustomDisplayEmailForThirdPartyMeetings>guest@microsoft.com</CustomDisplayEmailForThirdPartyMeetings>
<BluetoothAdvertisementEnabled>false</BluetoothAdvertisementEnabled>
<AutoAcceptProximateMeetingInvitations>true</AutoAcceptProximateMeetingInvitations>
<CortanaWakewordEnabled>true</CortanaWakewordEnabled>
<DualScreenMode>0</DualScreenMode>
<DuplicateIngestDefault>true</DuplicateIngestDefault>
<DisableTeamsAudioSharing>true</DisableTeamsAudioSharing>
<SendLogs>
  <EmailAddressForLogsAndFeedback>username@microsoft.com</EmailAddressForLogsAndFeedback>
  <SendLogsAndFeedback>True</SendLogsAndFeedback>
</SendLogs>
<Devices>
  <MicrophoneForCommunication>Device1</MicrophoneForCommunication>
  <SpeakerForCommunication>DeviceX</SpeakerForCommunication>
  <DefaultSpeaker>DeviceX</DefaultSpeaker>
  <ContentCameraId>Camera1</ContentCameraId>
  <ContentCameraEnhancement>true</ContentCameraEnhancement>
  <ContentCameraInverted>false</ContentCameraInverted>
</Devices>
<Theming>
 <ThemeName>Custom</ThemeName>
 <CustomThemeImageUrl>file name</CustomThemeImageUrl>
 <CustomThemeColor>
 <RedComponent>100</RedComponent>
 <GreenComponent>100</GreenComponent>
 <BlueComponent>100</BlueComponent>
</CustomThemeColor>
</Theming>
<CoordinatedMeetings enabled="true">
  <TrustedAccounts>username1@microsoft.com,username2@contoso.com</TrustedAccounts>
  <Settings>
    <Audio default="true" enabled="true"/>
    <Video default="true" enabled="true"/>
    <Whiteboard default="true" enabled="true"/>
  </Settings>
</CoordinatedMeetings>
</SkypeSettings>'

#Apply config
If(Test-Path $ConfigFile){
    Set-Content $ConfigFile $Config
} else {
    New-Item $ConfigFile -ItemType File
    Set-Content $ConfigFile $Config
}

#Apply background image
Invoke-WebRequest -Uri $BackgroundImage -OutFile $BackgroundFile
