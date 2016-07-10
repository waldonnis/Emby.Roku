'********************************************************************
'**  Emby Roku Client - Main
'********************************************************************

Sub Main()

	'deleteReg ("")  ' Delete all sections
	
	'Initialize globals
	initGlobals()

	'Initialize theme
	'prepare the screen for display and get ready to begin
	viewController = createViewController()
	
	'RunScreenSaver()
	viewController.Show()

End Sub

'
' Delete the entire registry or an individual registry section
'
Function deleteReg (section = "" As String) As Void
	r = CreateObject ("roRegistry")
	If section = ""
		For Each regSection In r.GetSectionList ()
			r.Delete (regSection)
		End For
	Else
		r.Delete (section)
	Endif
	r.Flush ()
End Function

'*************************************************************
'** Setup Global variables for the application
'*************************************************************

Sub initGlobals()
	device = CreateObject("roDeviceInfo")

	' Get device software version
	version = device.GetVersion()
	major = Mid(version, 3, 1).toInt()
	minor = Mid(version, 5, 2).toInt()
	build = Mid(version, 8, 5).toInt()
	versionStr = major.toStr() + "." + minor.toStr() + " build " + build.toStr()

	GetGlobalAA().AddReplace("rokuVersion", [major, minor, build])

	' Get channel version
	manifest = ReadAsciiFile("pkg:/manifest")
	lines = manifest.Tokenize(chr(10))

	For each line In lines
		entry = line.Tokenize("=")

		If entry[0]="version" Then
			Debug("--" + entry[1] + "--")
			GetGlobalAA().AddReplace("channelVersion", MID(entry[1], 0, 4))
			Exit For
		End If
	End For

	GetGlobalAA().AddReplace("rokuUniqueId", device.GetDeviceUniqueId())

	di = CreateObject("roDeviceInfo")
	modelName   = di.GetModelDisplayName()
	modelNumber = di.GetModel()

	' Initially set all to false to establish the entries
	' Any new audio codecs supported by Roku should be added here
	' excluding AAC and MP3 since those are supported on every model
	' and all 7.0+ firmware
	audioCodecs = {
		ac3:	false,		' AC-3
		dts:	false,		' DTS
		eac3:	false,		' E-AC-3 (DD+)
		flac:	false,		' flac
		alac:	false,		' Apple Lossless
		wma:	false,		' WMA
		wmapro: false,		' WMA Pro
		pcm:	false,		' PCM/LPCM
	}

	' So far, UHD (Roku 4 only so far) codecs
	' Initially set all to false to establish the entries
	' Any new video codecs supported by Roku should be added here
	' excluding h264 and mpeg4 since those are supported on every model
	' and all 7.0+ firmware
	videoCodecs = {
		vp9:	false,		' VP9
		hevc:	false,		' HEVC
	}

	' So far, only UHD (Roku 4 only so far) codecs support these
	' Initially set all to false to establish the entries
	' Any new HDR methods supported by Roku should be added here
	hdrSupport = {
		Hdr10:			false,	' Hdr10
		DolbyVision:	false,	' Dolby Vision
	}

	' Generic HDR support indicator
	hasHDR = false

	' Iterate through audio codec list and check if they're supported by the Roku
	for each ac in audioCodecs
		audioCodecs[ac] = di.CanDecodeAudio({ Codec: tostr(ac) }).result
		Debug("-- Audio codec support: " + tostr(ac) + " - " + tostr(audioCodecs[ac]))
	end for

	' Store audioCodecs globally
	GetGlobalAA().AddReplace("audioCodecs", audioCodecs)
	GetGlobalAA().AddReplace("surroundSound", (audioCodecs.ac3 or audioCodecs.dts or audioCodecs.eac3))

	' Iterate through video codec list and check if they're supported by the Roku
	for each vc in videoCodecs
		videoCodecs[vc] = di.CanDecodeVideo({ Codec: tostr(vc) }).result
		Debug("-- Video codec support: " + tostr(vc) + " - " + tostr(videoCodecs[vc]))
	end for

	' Store videoCodecs globally
	GetGlobalAA().AddReplace("videoCodecs", videoCodecs)

	' Check for Hdr10 and Dolby Vision (mostly Roku 4 for now) and set global vars
	' FIXME: Supposedly this can be done with CanDecodeVideo(), but it's weird
	' and I can't verify the result without a Roku 4 on a 4k monitor that supports it,
	' so use GetDisplayProperties() for now.
	for each hdrType in hdrSupport
		hdrSupport[hdrType] = di.GetDisplayProperties()[hdrType]
		hasHDR = hasHDR or hdrSupport[hdrType]
		Debug("-- HDR support: " + tostr(hdrType) + " - " + tostr(hdrSupport[hdrType]))
	end for
	Debug("-- HDR support detected: " + tostr(hasHDR))

	' Store hdrSupport and hasHDR globally
	GetGlobalAA().AddReplace("hdrSupport", hdrSupport)
	GetGlobalAA().AddReplace("hasHDR", hasHDR)

	GetGlobalAA().AddReplace("rokuModelNumber", modelNumber)
	GetGlobalAA().AddReplace("rokuModelName", modelName)

	' Support for ReFrames seems mixed. These numbers could be wrong, but
	' there are reports that the Roku 1 can't handle more than 5 ReFrames,
	' and testing has shown that the video is black beyond that point. The
	' Roku 2 has been observed to play all the way up to 16 ReFrames, but
	' on at least one test video there were noticeable artifacts as the
	' number increased, starting with 8.
	if left(modelNumber,1) = "4" and major >=5 then
		GetGlobalAA().AddReplace("maxRefFrames", 15)
	elseif major >= 4 then
		GetGlobalAA().AddReplace("maxRefFrames", 8)
	else
		GetGlobalAA().AddReplace("maxRefFrames", 5)
	end if

	' Check if HDTV screen
	If device.GetDisplayType() = "HDTV" Then
		GetGlobalAA().AddReplace("isHD", true)
	Else
		GetGlobalAA().AddReplace("isHD", false)
	End If

	' Get display information
	GetGlobalAA().AddReplace("displaySize", device.GetDisplaySize())
	GetGlobalAA().AddReplace("displayMode", device.GetDisplayMode())
	GetGlobalAA().AddReplace("displayType", device.GetDisplayType())

	SupportsSurroundSound()
	
End Sub


'*************************************************************
'** Get a variable from the Global Array
'*************************************************************

Function getGlobalVar(name, default=invalid)
	Return firstOf(GetGlobalAA().Lookup(name), default)
End Function

Function SupportsSurroundSound(transcoding=false, refresh=false) As Boolean

	if m.SurroundSoundTimer = invalid then
		refresh = true
		m.SurroundSoundTimer = CreateTimer()
	else if m.SurroundSoundTimer.GetElapsedSeconds() > 10 then
		refresh = true
	end if

	if refresh then
		device = CreateObject("roDeviceInfo")
		result = device.HasFeature("5.1_surround_sound")
		GetGlobalAA().AddReplace("surroundSound", result)
		m.SurroundSoundTimer.Mark()
	else
		result = getGlobalVar("surroundSound")
	end if

	return result
End Function

Function CheckMinimumVersion(versionArr, requiredVersion) As Boolean
	index = 0
	for each num in versionArr
		if index >= requiredVersion.count() then exit for
		if num < requiredVersion[index] then
			return false
		else if num > requiredVersion[index] then
			return true
		end if
		index = index + 1
	next
	return true
End Function

Function IsActiveSupporter() as Boolean

	' URL
	url = GetServerBaseUrl() + "/Plugins/SecurityInfo"

	' Prepare Request
	request = HttpRequest(url)
	request.ContentType("json")
	request.AddAuthorization()

	' Execute Request
	response = request.GetToStringWithTimeout(10)
	
	if response <> invalid then
		
		userInfo = ParseJSON(response)
		
		if userInfo <> invalid then
			return userInfo.IsMBSupporter
		end if
	
	end if
	
	return false
	
End Function
