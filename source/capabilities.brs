'******************************************************
' Creates the capabilities object that is reported to Emby servers
'******************************************************

Function getDirectPlayProfiles()

	profiles = []
	
	versionArr = getGlobalVar("rokuVersion")
	device = CreateObject("roDeviceInfo")

	audioContainers = "mp3,wma"
	mp4Audio = "aac,mp3"
	mp4Video = "h264,mpeg4"
	mkvAudio = "aac,mp3"
	mkvVideo = "h264,mpeg4"

	' Call new CanDecodeX functions to check which a/v formats are supported by the device
	' rather than relying on model numbers and firmware revisions. These checks
	' rely on Roku firmware v7.0 or greater.  Each codec is checked for container support
	' as well.
	' Should be easier to add new supported format checks in a model- and revision-agnostic manner
	' with this scheme

	' audioContainer support checks
	if device.CanDecodeAudio({Codec: "flac"}).result then audiocontainers += ",flac"
	if device.CanDecodeAudio({Codec: "alac"}).result then audiocontainers += ",alac"

	' mp4Audio support checks - commented out eac3 since Emby doesn't distinguish ac3/eac3
	' by name (only channel count).  If this ever changes, just uncomment those lines
	if device.CanDecodeAudio({Codec: "ac3", Container: "mp4"}).result then mp4Audio += ",ac3"
	'if device.CanDecodeAudio({Codec: "eac3", Container: "mp4"}).result then mp4Audio += ",eac3"
	if device.CanDecodeAudio({Codec: "dts", Container: "mp4"}).result then mp4Audio += ",dca"

	' mkvAudio support checks - same note above applies to eac3
	if device.CanDecodeAudio({Codec: "ac3", Container: "mkv"}).result then mkvAudio += ",ac3"
	'if device.CanDecodeAudio({Codec: "eac3", Container: "mp4"}).result then mp4Audio += ",eac3"
	if device.CanDecodeAudio({Codec: "dts", Container: "mkv"}).result then mkvAudio += ",dca"
	if device.CanDecodeAudio({Codec: "flac", Container: "mkv"}).result then mkvAudio += ",flac"

	' mkvVideo support checks - these are for hevc/vp9 (4k UHD).  Only the Roku 4 should support
	' these for now, and only in mkv containers
	if device.CanDecodeVideo({Codec: "hevc", Container: "mkv"}).result then mkvVideo += ",hevc"
	if device.CanDecodeVideo({Codec: "vp9", Container: "mkv"}).result then mkvVideo += ",vp9"

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
	
	profiles.push({
		Type: "Audio"
		Container: "mp3"
		AudioCodec: "mp3"
		Context: "Streaming"
		Protocol: "Http"
	})
	
	hlsVideoCodec = "h264"
	hlsAudioCodec = "mp3,aac"
	
	' Check audio surround codec support for hls
	if device.CanDecodeAudio({Codec: "ac3", Container: "hls"}).result then hlsAudioCodec += ",ac3"
	if device.CanDecodeAudio({Codec: "dts", Container: "hls"}).result then hlsAudioCodec += ",dca"

	' Check video codec support for hls (mostly just checking hevc/vp9 for now)
	if device.CanDecodeVideo({Codec: "hevc", Container: "hls"}).result then hlsVideoCodec += ",hevc"
	if device.CanDecodeVideo({Codec: "vp9", Container: "hls"}).result then hlsVideoCodec += ",vp9"
	
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
	playsAnamorphic = firstOf(getGlobalVar("playsAnamorphic"), false)
 	device = CreateObject("roDeviceInfo")
	model = left(device.GetModel(),4)
	
	maxWidth = "1920"
	maxHeight = "1080"
	max4kWidth = "3840"
	max4kHeight = "2160"
	
	if getGlobalVar("displayType") <> "HDTV" then
		maxWidth = "1280"
		maxHeight = "720"
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
	if playsAnamorphic = false Then
		h264Conditions.push({
			Condition: "Equals"
			Property: "IsAnamorphic"
			Value: "false"
			IsRequired: false
		})
	end if
	
	' Check for codec support rather than the old model check
	' FIX: This still needs to be cleaned up since a Roku4 may still be
	' connected to a 1080p monitor, meaning transcoding may still be
	' necessary, but I don't know if the device downscales automatically.
	if device.CanDecodeVideo({Codec: "hevc"}).result then
		hevcConditions = []
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
	
	' Check for vp9 codec support (Roku 4 only so far).  Same note from hevc above
	' applies here re: FIX
	if device.CanDecodeVideo({Codec: "vp9"}).result then
		vp9Conditions = []
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
	
	profiles.push({
		Type: "Video"
		Codec: "h264"
		Conditions: h264Conditions
	})
	
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
	if playsAnamorphic = false Then
		mpeg4Conditions.push({
			Condition: "Equals"
			Property: "IsAnamorphic"
			Value: "false"
			IsRequired: false
		})
	end if
	
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
	
	' FIX: why is the commented condition here?  Do some Rokus not support
	' audio stream selection??  It causes ac3 tracks to transcode if they're not
	' the first streamindex, which goes against the "first track should be aac" thing
	profiles.push({
		Type: "VideoAudio"
		Codec: "ac3"
		Conditions: [{
		'	Condition: "Equals"
		'	Property: "IsSecondaryAudio"
		'	Value: "false"
		'	IsRequired: false
		'},
		'{
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

    if major < 4 then
		' If everything else looks ok and there are no audio streams, that's
		' fine on Roku 2+.
		videoContainerConditions.push({
			Condition: "NotEquals"
			Property: "NumAudioStreams"
			Value: "0"
			IsRequired: false
		})
	end if
	
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
