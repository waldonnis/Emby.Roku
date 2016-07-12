'******************************************************
' Creates the capabilities object that is reported to Emby servers
'******************************************************

Function getDirectPlayProfiles()

	profiles = []
	
	versionArr = getGlobalVar("rokuVersion")
	device = CreateObject("roDeviceInfo")

	audioCodecs = getGlobalVar("audioCodecs")
	videoCodecs = getGlobalVar("videoCodecs")

	renameDTS = CreateObject("roRegex", "^dts$", "")

	audioContainers = "mp3,wma"
	mp4Audio = "aac,mp3"
	mp4Video = "h264,mpeg4"
	mkvAudio = "aac,mp3"
	mkvVideo = "h264,mpeg4"

	' audioContainer support checks
	if audioCodecs.flac then audiocontainers += ",flac"
	if audioCodecs.alac then audiocontainers += ",alac"

	for each acodec in audioCodecs
		if audioCodecs[acodec] then
			if device.CanDecodeAudio({Codec: acodec, Container: "mp4"}).result then
				mp4Audio += "," + renameDTS(tostr(acodec), "dca")
			end if
			if device.CanDecodeAudio({Codec: acodec, Container: "mkv"}).result then
				mkvAudio += "," + renameDTS(tostr(acodec), "dca")
			end if
		end if
	end for

	Debug("-- mp4 audio codecs: " + mp4Audio)
	Debug("-- mkv audio codecs: " + mkvAudio)

	for each vcodec in videoCodecs
		if videoCodecs[vcodec] then
			if device.CanDecodeVideo({Codec: vcodec, Container: "mkv"}).result then
				mkvVideo += "," + tostr(vcodec)
			end if
		end if
	end for
	Debug("-- mkv video codecs: " + mkvVideo)

	profiles.push({
		Type: "Audio"
		Container: audioContainers
	})
	
	profiles.push({
		Type: "Video"
		Container: "mp4,mov,m4v"
		VideoCodec: "h264,mpeg4"
		AudioCodec: mp4Audio
	})
		
	profiles.push({
		Type: "Video"
		Container: "mkv"
		VideoCodec: mkvVideo
		AudioCodec: mkvAudio
	})

	return profiles

End Function

Function getTranscodingProfiles()

	profiles = []
	versionArr = getGlobalVar("rokuVersion")
	device = CreateObject("roDeviceInfo")
	
	audioCodecs = getGlobalVar("audioCodecs")
	videoCodecs = getGlobalVar("videoCodecs")

	renameDTS = CreateObject("roRegex", "^dts$", "")

	profiles.push({
		Type: "Audio"
		Container: "mp3"
		AudioCodec: "mp3"
		Context: "Streaming"
		Protocol: "Http"
	})
	
	hlsVideoCodec = "h264"
	hlsAudioCodec = "mp3,aac"
	
	' Check audio codec support for hls
	for each acodec in audioCodecs
		if audioCodecs[acodec] then
			if device.CanDecodeAudio({Codec: acodec, Container: "hls"}).result then
				hlsAudioCodec += "," + renameDTS(tostr(acodec), "dca")
			end if
		end if
	end for
	Debug("-- hls audio codecs: " + hlsAudioCodec)

	' Check video codec support for hls
	for each vcodec in videoCodecs
		if videoCodecs[vcodec] then
			if device.CanDecodeVideo({Codec: vcodec, Container: "hls"}).result then
				hlsVideoCodec += "," + tostr(vcodec)
			end if
		end if
	end for
	Debug("-- hls video codecs: " + hlsVideoCodec)

	profiles.push({
		Type: "Video"
		Container: "ts"
		AudioCodec: hlsAudioCodec
		VideoCodec: hlsVideoCodec
		Context: "Streaming"
		Protocol: "Hls"
	})

	return profiles

End Function

Function getCodecProfiles()

	profiles = []

	maxRefFrames = firstOf(getGlobalVar("maxRefFrames"), 12)
 	device = CreateObject("roDeviceInfo")
	displaySize = getGlobalVar("displaySize")
	videoCodecs = getGlobalVar("videoCodecs")
	hasHDR = getGlobalVar("hasHDR")
	hdrSupport = getGlobalVar("hdrSupport")

	maxWidth = "1920"
	maxHeight = "1080"
	max4kWidth = "3840"
	max4kHeight = "2160"

	if getGlobalVar("displayType") <> "HDTV" then
		maxWidth = displaySize.w
		maxHeight = displaySize.h
	end if

	' HDR support check, and increase bit depth accordingly
	' FIXME: this needs to be worked on more, as the HDR implementations so far
	' are not compatible and it's not this simple.  Server-side profile checks
	' will likely be needed to distinguish which method is used in the files and adjust
	' bit depth for just those files (use hdrSupport AA bools for that).
	' Dolby Vision supports 12bpp colour, but I'm not sure the Roku does yet.  Docs
	' indicate that it may just support 10bpp (GetVideoMode() return values), but including
	' 12bpp capabilities until we can confirm it one way or the other.
	if hasHDR then
		if hdrSupport.DolbyVision then
			max4kBitDepth = "12"
		else
			max4kBitDepth = "10"
		end if
	else
		max4kBitDepth = "8"
	end if
	
	h264Conditions = []
	h264Conditions.push({
		Condition: "LessThanEqual"
		Property: "RefFrames"
		Value: tostr(maxRefFrames)
		IsRequired: false
	})
	h264Conditions.push({
		Condition: "LessThanEqual"
		Property: "VideoBitDepth"
		Value: "8"
		IsRequired: false
	})
	h264Conditions.push({
		Condition: "LessThanEqual"
		Property: "Width"
		Value: maxWidth
		IsRequired: true
	})
	h264Conditions.push({
		Condition: "LessThanEqual"
		Property: "Height"
		Value: maxHeight
		IsRequired: true
	})
	h264Conditions.push({
		Condition: "LessThanEqual"
		Property: "VideoFramerate"
		Value: "30"
		IsRequired: false
	})
	h264Conditions.push({
		Condition: "EqualsAny"
		Property: "VideoProfile"
		Value: "high|main|baseline|constrained baseline"
		IsRequired: false
	})
	h264Conditions.push({
		Condition: "LessThanEqual"
		Property: "VideoLevel"
		Value: "50"
		IsRequired: false
	})
	
	profiles.push({
		Type: "Video"
		Codec: "h264"
		Conditions: h264Conditions
	})
	
	' Check for codec support rather than the old model check
	' Apparently, the Roku 4 automatically downscales 4k content
	' if it's not connected to a 4k monitor, so we can use 4k max
	' width/height vals.
	if videoCodecs.hevc then
		hevcConditions = []
		hevcConditions.push({
			Condition: "LessThanEqual"
			Property: "VideoBitDepth"
			Value: max4kBitDepth
			IsRequired: false
		})
		hevcConditions.push({
			Condition: "LessThanEqual"
			Property: "Width"
			Value: max4kWidth
			IsRequired: true
		})
		hevcConditions.push({
			Condition: "LessThanEqual"
			Property: "Height"
			Value: max4kHeight
			IsRequired: true
		})
		hevcConditions.push({
			Condition: "LessThanEqual"
			Property: "VideoFramerate"
			Value: "60"
			IsRequired: false
		})

		profiles.push({
			Type: "Video"
			Codec: "hevc"
			Conditions: hevcConditions
		})
	endif 
	
	' Check for vp9 codec support (Roku 4 only so far).
	' Same note from hevc above
	if videoCodecs.vp9 then
		vp9Conditions = []
		vp9Conditions.push({
			Condition: "LessThanEqual"
			Property: "VideoBitDepth"
			Value: max4kBitDepth
			IsRequired: false
		})
		vp9Conditions.push({
			Condition: "LessThanEqual"
			Property: "Width"
			Value: max4kWidth
			IsRequired: true
		})
		vp9Conditions.push({
			Condition: "LessThanEqual"
			Property: "Height"
			Value: max4kHeight
			IsRequired: true
		})
		vp9Conditions.push({
			Condition: "LessThanEqual"
			Property: "VideoFramerate"
			Value: "30"
			IsRequired: false
		})

		profiles.push({
			Type: "Video"
			Codec: "vp9"
			Conditions: vp9Conditions
		})
	end if ' roku 4
	
	mpeg4Conditions = []
	mpeg4Conditions.push({
		Condition: "LessThanEqual"
		Property: "RefFrames"
		Value: tostr(maxRefFrames)
		IsRequired: false
	})
	mpeg4Conditions.push({
		Condition: "LessThanEqual"
		Property: "VideoBitDepth"
		Value: "8"
		IsRequired: false
	})
	mpeg4Conditions.push({
		Condition: "LessThanEqual"
		Property: "Width"
		Value: maxWidth
		IsRequired: true
	})
	mpeg4Conditions.push({
		Condition: "LessThanEqual"
		Property: "Height"
		Value: maxHeight
		IsRequired: true
	})
	mpeg4Conditions.push({
		Condition: "LessThanEqual"
		Property: "VideoFramerate"
		Value: "30"
		IsRequired: false
	})
	mpeg4Conditions.push({
		Condition: "NotEquals"
		Property: "CodecTag"
		Value: "DX50"
		IsRequired: false
	})
	mpeg4Conditions.push({
		Condition: "NotEquals"
		Property: "CodecTag"
		Value: "XVID"
		IsRequired: false
	})
	
	profiles.push({
		Type: "Video"
		Codec: "mpeg4"
		Conditions: mpeg4Conditions
	})
		
	profiles.push({
		Type: "VideoAudio"
		Codec: "mp3"
		Conditions: [{
			Condition: "Equals"
			Property: "IsSecondaryAudio"
			Value: "false"
			IsRequired: false
		},
		{
			Condition: "LessThanEqual"
			Property: "AudioChannels"
			Value: "2"
			IsRequired: true
		}]
	})
	
	' Check to see if the device can decode 6-channel AAC. I think
	' only the Roku 4 can so far, but this should work on any device
	' that can (or pass it through) in case that assumption is incorrect.
	if device.CanDecodeAudio({Codec: "aac", ChCnt: 6}).result then
		AACchannels = "6"
	else
		AACchannels = "2"
	end if
	
	profiles.push({
		Type: "VideoAudio"
		Codec: "aac"
		Conditions: [{
			Condition: "Equals"
			Property: "IsSecondaryAudio"
			Value: "false"
			IsRequired: false
		},
		{
			Condition: "LessThanEqual"
			Property: "AudioChannels"
			Value: AACchannels
			IsRequired: true
		}]
	})
		
	' Check to see if the device can decode/pass-through eac3 with 8 channels.
	' If not, fall back to regular 6-channel ac3 support.
	if device.CanDecodeAudio({Codec: "eac3", ChCnt: 8}).result then
		ac3Channels = "8"
	else
		ac3Channels = "6"
	end if
	
	profiles.push({
		Type: "VideoAudio"
		Codec: "ac3"
		Conditions: [{
			Condition: "LessThanEqual"
			Property: "AudioChannels"
			Value: ac3Channels
			IsRequired: false
		}]
	})
	
	return profiles

End Function

Function getContainerProfiles()

	profiles = []

	videoContainerConditions = []
	
	versionArr = getGlobalVar("rokuVersion")
    major = versionArr[0]

	' Multiple video streams aren't supported, regardless of type.
    videoContainerConditions.push({
		Condition: "Equals"
		Property: "NumVideoStreams"
		Value: "1"
		IsRequired: false
	})
		
	profiles.push({
		Type: "Video"
		Conditions: videoContainerConditions
	})
	
	return profiles

End Function

Function getSubtitleProfiles()

	profiles = []
	
	profiles.push({
		Format: "srt"
		Method: "External"
		
		' If Roku adds support for non-Latin characters, remove this
		Language: "und,afr,alb,baq,bre,cat,dan,eng,fao,glg,ger,ice,may,gle,ita,lat,ltz,nor,oci,por,roh,gla,spa,swa,swe,wln,est,fin,fre,dut"
	})
	
	profiles.push({
		Format: "srt"
		Method: "Embed"
		
		' If Roku adds support for non-Latin characters, remove this
		Language: "und,afr,alb,baq,bre,cat,dan,eng,fao,glg,ger,ice,may,gle,ita,lat,ltz,nor,oci,por,roh,gla,spa,swa,swe,wln,est,fin,fre,dut"
	})
			
	return profiles

End Function

Function getDeviceProfile() 

	maxVideoBitrate = firstOf(RegRead("prefVideoQuality"), "3200")
	maxVideoBitrate = maxVideoBitrate.ToInt() * 1000
	
	profile = {
		MaxStaticBitrate: "40000000"
		MaxStreamingBitrate: tostr(maxVideoBitrate)
		MusicStreamingTranscodingBitrate: "192000"
		
		DirectPlayProfiles: getDirectPlayProfiles()
		TranscodingProfiles: getTranscodingProfiles()
		CodecProfiles: getCodecProfiles()
		ContainerProfiles: getContainerProfiles()
		SubtitleProfiles: getSubtitleProfiles()
		Name: "Roku"
	}
	
	return profile
	
End Function

Function getCapabilities() 

	caps = {
		PlayableMediaTypes: ["Audio","Video","Photo"]
		SupportsMediaControl: true
		SupportedCommands: ["MoveUp","MoveDown","MoveLeft","MoveRight","Select","Back","GoHome","SendString","GoToSearch","GoToSettings","DisplayContent","SetAudioStreamIndex","SetSubtitleStreamIndex"]
		MessageCallbackUrl: ":8324/emby/message"
		DeviceProfile: getDeviceProfile()
		SupportedLiveMediaTypes: ["Video"]
		AppStoreUrl: "https://www.roku.com/channels#!details/44191/emby"
		IconUrl: "https://raw.githubusercontent.com/wiki/MediaBrowser/Emby.Roku/Images/icon.png"
	}
	
	return caps
	
End Function
