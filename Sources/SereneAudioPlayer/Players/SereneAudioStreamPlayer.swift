//
//  SereneAudioStreamPlayer.swift
//
//  Created by Amr Al-Refae on 2020-05-31.
//  Copyright © 2020 Amr Al-Refae. All rights reserved.
//

import SwiftUI
import AVFoundation
import MediaPlayer
import ActivityIndicatorView
import Kingfisher
import AVKit
import Combine

public struct SereneAudioStreamPlayer: View {
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.presentationMode) var presentationMode
    
    var track: Track
    var folderName: String
    var layout: Layout
    var likeAction: () -> Bool
    var shareAction: () -> Void
    var onDismiss: (Bool) -> Void
    var onFinish: () -> Void
    @State var isSeen = false
    @State var isOSMediaInfoActivated = false
    
    @State var currentSelectedMenu = String()
    
    @State var trackFavourited: Bool = false
    
    @State var player : AVPlayer?
    @State var looperPlayer: AVPlayerLooper?
    @State var noiseLooperPlayer: AVPlayerLooper?
    @State var backgroundPlayer: AVPlayer?
    @State var noisePlayer: AVPlayer?
    @State var playing = false
    @State var width: CGFloat = 0
    @State var finish = false
    
    @State var downloaded = false
    @State var disableDownload = false
    @State var showingAlert = false
    
    @State var isDownloading = false
    
    @State var assetCurrentDuration: TimeInterval = .zero
    @State var assetDuration: TimeInterval = .zero
    @State private var playerItemBufferKeepUpObserver: NSKeyValueObservation?
    
    @State private var backgroundPlayerOpacity: Double = 0
    
    let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    private var streamURL: URL {
        let urlString = self.track.streamURL ?? ""
        
        let encodedSoundString = urlString.removingPercentEncoding?.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
        
        let url = URL(string: encodedSoundString!)!
        
        return url
    }
    
    public init(
        track: Track,
        layout: Layout,
        folderName: String,
        likeAction: @escaping () -> Bool,
        shareAction: @escaping () -> Void,
        onDismiss: @escaping (Bool) -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.track = track
        self.layout = layout
        self.folderName = folderName
        self.likeAction = likeAction
        self.shareAction = shareAction
        self.onDismiss = onDismiss
        self.onFinish = onFinish
    }
    
    var likeButtonView: some View {
        Button(action: {
            trackFavourited = likeAction()
        }) {
            
            if track.favorited == true {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color(UIColor(red: 58, green: 127, blue: 123, alpha: 1)))
                    .font(.headline)
                    .padding()
            } else {
                Image(systemName: "heart")
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding()
            }
            
        }
    }
    
    var playButtonView: some View {
        Button(action: {
            if InternetConnectionManager.isConnectedToNetwork() {
                print("Internet connection OK")
                
                
                if self.player?.isPlaying == true {
                    self.noisePlayer?.pause()
                    self.player?.pause()
                    self.playing = false
                } else {
                    
                    if self.finish {
                        self.player?.seek(to: .zero)
                        self.noisePlayer?.seek(to: .zero)
                        self.backgroundPlayer?.seek(to: .zero)
                        self.width = 0
                        self.finish = false
                        self.assetCurrentDuration = 0
                    }
                    
                    self.noisePlayer?.play()
                    self.player?.playImmediately(atRate: 1)
                    self.playing = true
                    
                }
            } else {
                print("Internet connection FAILED")
                
                self.showingAlert = true
                
            }
        }) {
            
            Image(systemName: self.playing && !self.finish ? "pause.fill" : "play.fill")
                .foregroundColor(.white)
                .font(.largeTitle)
                .frame(width: 80, height: 80)
                .background(.white.opacity(0.3))
                .clipShape(Circle())
        }
    }
    
    var backwardButtonView: some View {
        Button(action: {
            
            var timeBackward = self.player?.currentTime().seconds ?? 0
            timeBackward -= 15
            if assetCurrentDuration < 15 {
                assetCurrentDuration = 0
            } else {
                assetCurrentDuration = TimeInterval(timeBackward)
            }
            self.player?.seek(to: CMTime(seconds: timeBackward, preferredTimescale: self.player?.currentTime().timescale ?? 0))
        }) {
            Image(systemName: "gobackward.15")
                .foregroundColor(.white)
                .font(.headline)
                .padding()
        }
    }
    
    var airplayView: some View {
        Button(action: {
            
            
            
        }) {
            Image(systemName: "airplayvideo")
                .foregroundColor(.white)
                .font(.headline)
        }
    }
    
    var backgroundVideo: (url: URL, volume: Float)? {
        if let backgroundAnimationURL = track.animation.backgroundAnimationURL,
           let encodedAnimationString = backgroundAnimationURL.removingPercentEncoding?.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
           let animationURL = URL(string: encodedAnimationString) {
            let volume = Float(track.animation.backgroundVolume ?? 0) / 100
            
            return (animationURL, volume)
            
        } else {
            return nil
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background Image of current track
                KFImage(URL(string: track.image ?? ""))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width)
                    .edgesIgnoringSafeArea(.vertical)
                
                // Background Video Player
                
                if backgroundPlayer != nil {
                    VideoPlayerView(player: $backgroundPlayer, isAudioPlayed: $playing) {
                        backgroundPlayerOpacity = 1
                        noisePlayer?.play()
                    }
                    .opacity(backgroundPlayerOpacity)
                    .ignoresSafeArea()
                    .disabled(true)
                    .onDisappear {
                        backgroundPlayer?.pause()
                        backgroundPlayer = nil
                    }
                    
                    VideoPlayerView(player: $noisePlayer, isAudioPlayed: $playing) { }
                    .opacity(0)
                    .ignoresSafeArea()
                    .disabled(true)
                    .onDisappear {
                        noisePlayer?.pause()
                        noisePlayer = nil
                    }
                }
                
                // Gradient Overlay (Clear to Black)
                VStack {
                    Spacer()
                    Rectangle()
                        .foregroundColor(.clear)
                        .background(LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom))
                        .edgesIgnoringSafeArea(.bottom)
                        .frame(height: UIScreen.main.bounds.height / 1.5)
                }
                
                VStack(alignment: .leading) {
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text(track.title ?? "No track title")
                            .foregroundColor(.white)
                            .font(.custom("Helvetica Neue", size: 32))
                            .fontWeight(.bold)
                            .padding(.bottom, 8)
                            .multilineTextAlignment(.leading)
                        
                        Text(track.subtitle ?? "No track subtitle")
                            .foregroundColor(.white)
                            .font(.custom("Helvetica Neue", size: 20))
                            .fontWeight(.medium)
                            .padding(.bottom, 30)
                    }
                    .padding(.horizontal)
                    
                    VStack {
                        ZStack(alignment: .leading) {
                            
                            if layout == .music {
                                Image(.liveAudio)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Capsule().fill(Color.white.opacity(0.08)).frame(height: 5)
                                
                                Capsule().fill(Color.white).frame(width: self.width, height: 5)
                                    .gesture(DragGesture()
                                        .onChanged({ (value) in
                                            
                                            let x = value.location.x
                                            
                                            self.width = x
                                            
                                        }).onEnded({ (value) in
                                            
                                            let x = value.location.x
                                            
                                            let screen = UIScreen.main.bounds.width - 30
                                            
                                            let percent = x / screen
                                            
                                            Task {
                                                if let seconds = try await self.player?.currentItem?.asset.load(.duration).seconds {
                                                    let seek = Double(percent) * seconds
                                                    
                                                    await self.player?.seek(to: CMTime(seconds: seek, preferredTimescale: self.player?.currentTime().timescale ?? 0))
                                                    
                                                    assetCurrentDuration = TimeInterval(seek)
                                                }
                                            }
                                        }))
                            }
                        }
                        .padding(.horizontal)
                        if layout != .music {
                            HStack {
                                Text(durationFormatter.string(from: assetCurrentDuration)!)
                                Spacer()
                                if !assetDuration.isNaN && !assetDuration.isInfinite {
                                    Text(durationFormatter.string(from: assetDuration)!)
                                }
                            }
                            .foregroundStyle(.white)
                            .font(.custom("Helvetica Neue", size: 12))
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                    
                    HStack(alignment: .center, spacing: 32) {
                        
                        airplayView
                        
                        
                        if layout == .classCollection {
                            backwardButtonView
                        }
                        
                        playButtonView
                        
                        if layout == .classCollection {
                            likeButtonView
                        }
                        
                        switch layout {
                        case .music, .unguided, .intro, .classCollection:
                            KebabMenuView(options: [
                                KebabMenuModel(text: "Share", icon: .share)
                            ], currentSelection: $currentSelectedMenu)
                        case .unknown:
                            Button(action: {
                                let urlString = self.track.streamURL ?? ""
                                
                                let encodedSoundString = urlString.removingPercentEncoding?.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
                                
                                self.downloadAndSaveAudioFile(encodedSoundString!) { (url) in
                                    self.downloaded = true
                                    self.disableDownload = true
                                }
                            }) {
                                
                                if isDownloading {
                                    ActivityIndicatorView(isVisible: $isDownloading, type: .default)
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(.white)
                                        .padding()
                                } else {
                                    if downloaded {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                            .padding()
                                    } else {
                                        
                                        Image(systemName: "icloud.and.arrow.down.fill")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                            .padding()
                                    }
                                }
                                
                                
                            }
                            .disabled(disableDownload)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                    .onAppear {
                        
                        if InternetConnectionManager.isConnectedToNetwork() {
                            print("Internet connection OK")
                        } else {
                            print("Internet connection FAILED")
                            
                            self.showingAlert = true
                            
                        }
                        
                        // MARK: - sound player handler
                        
                        let playerItem = AVPlayerItem(url: streamURL)
                        
                        player = AVPlayer(playerItem: playerItem)
                        
                        player?.allowsExternalPlayback = true
                        
                        playerItemBufferKeepUpObserver = player?.currentItem?.observe(\AVPlayerItem.isPlaybackLikelyToKeepUp, options: [.new]) { _,_  in
                            assetDuration = playerItem.duration.seconds
                            player?.play()
                            playing = true
                            if isOSMediaInfoActivated == false {
                                setupNowPlaying(track: track)
                                setupRemoteTransportControls()
                                isOSMediaInfoActivated = true
                            }
                            
                        }
                        
                        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                            
                            if self.player?.isPlaying == true {
                                
                                let screen = UIScreen.main.bounds.width - 30
                                
                                let seconds = Float(player?.currentItem?.duration.seconds ?? 0)
                                let value = Float(self.player?.currentItem!.currentTime().seconds ?? 0) / seconds
                                self.width = screen * CGFloat(value)
                                assetCurrentDuration += 1
                                if getPercentComplete(currentDuration: assetCurrentDuration, totalDuration: assetDuration) > 75 {
                                    isSeen = true
                                }
                            }
                        }

                        NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: self.player?.currentItem, queue: .main) { _ in
                            if layout == .music {
                                self.player?.seek(to: .zero)
                                self.player?.play()
                            } else {
                                self.finish = true
                                self.backgroundPlayer = nil
                                self.noisePlayer = nil
                                self.player = nil
                                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                                self.dismiss()
                                self.onFinish()
                            }
                        }
                    }
                    .alert(isPresented: $showingAlert) {
                        Alert(title: Text("No Internet Connection"), message: Text("Please ensure your device is connected to the internet."), dismissButton: .default(Text("Got it!")))
                        
                    }
                    .onChange(of: currentSelectedMenu) { value in
                        switch value {
                        case "Share":
                            shareAction()
                        case "Download":
                            break
                        default:
                            break
                        }
                        currentSelectedMenu = ""
                    }
                    
                }
            }
            .toolbar(content: {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        noisePlayer?.pause()
                        backgroundPlayer?.pause()
                        player?.pause()
                        
                        noisePlayer = nil
                        backgroundPlayer = nil
                        player = nil
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                        onDismiss(isSeen)
                        dismiss()
                    } label: {
                        Image(systemName: "multiply")
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
            })
        }
        .onAppear {
            setupBackgroundVideo()
        }
    }
    
    private func setupBackgroundVideo() {
        if let backgroundVideo {
            let asset = AVURLAsset(url: backgroundVideo.url)
            let playerItem = AVPlayerItem(asset: asset)
            let queuePlayer = AVQueuePlayer(playerItem: playerItem)
            looperPlayer = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
            backgroundPlayer = queuePlayer
            backgroundPlayer?.isMuted = true
            
            let noiseFile = Bundle.module.url(forResource: "Final Noise Track 20 min", withExtension: "mp3")!
            let noiseAsset = AVURLAsset(url: noiseFile)
            let noisePlayerItem = AVPlayerItem(asset: noiseAsset)
            let noiseQueuePlayer = AVQueuePlayer(playerItem: noisePlayerItem)
            noiseLooperPlayer = AVPlayerLooper(player: noiseQueuePlayer, templateItem: noisePlayerItem)
            
            noisePlayer = noiseQueuePlayer
            noisePlayer?.volume = backgroundVideo.volume
        }
    }
    
    func getPercentComplete(currentDuration: TimeInterval, totalDuration: TimeInterval) -> Double {
      guard totalDuration > 0 else { return 0 } // Handle cases where total duration is 0
      return (currentDuration / totalDuration) * 100
    }
    
    func setupRemoteTransportControls() {
        // Get the shared MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [self] event in
            if !(self.player?.isPlaying ?? false) {
                self.player?.play()
                self.noisePlayer?.play()
                self.playing = true
                return .success
            }
            return .commandFailed
        }
        
        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [self] event in
            if self.player?.isPlaying == true {
                self.player?.pause()
                self.noisePlayer?.pause()
                self.playing = false
                return .success
            }
            return .commandFailed
        }
        
    }
    
    func setupNowPlaying(track: Track) {
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        // Define Now Playing Info
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPNowPlayingInfoPropertyAssetURL] = streamURL
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title ?? "Unknown Name"
        
        DispatchQueue.global(qos: .background).async {
            if let imageString = track.thumbnail,
               let imageURL = URL(string: imageString),
               let data = try? Data(contentsOf: imageURL),
               let image = UIImage(data: data) {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { size in
                    return image
                }
            }
            
            nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime().seconds
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Float(player?.currentItem?.duration.seconds ?? 0)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate
        
        // Set the metadata
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }
    
    func downloadAndSaveAudioFile(_ audioFile: String, completion: @escaping (String) -> Void) {
        
        self.isDownloading.toggle()
        
        //Create directory if not present
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.libraryDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let documentDirectory = paths.first! as NSString
        let soundDirPathString = documentDirectory.appendingPathComponent(folderName)
        
        do {
            try FileManager.default.createDirectory(atPath: soundDirPathString, withIntermediateDirectories: true, attributes:nil)
            print("directory created at \(soundDirPathString)")
        } catch let error as NSError {
            print("error while creating dir : \(error.localizedDescription)");
        }
        
        if let audioUrl = URL(string: audioFile) {
            // create your document folder url
            let documentsUrl =  FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first! as URL
            let documentsFolderUrl = documentsUrl.appendingPathComponent(folderName)
            // your destination file url
            let destinationUrl = documentsFolderUrl.appendingPathComponent(audioUrl.lastPathComponent)
            
            print(destinationUrl)
            // check if it exists before downloading it
            if FileManager().fileExists(atPath: destinationUrl.path) {
                print("The file already exists at path")
                self.isDownloading.toggle()
            } else {
                //  if the file doesn't exist
                //  just download the data from your url
                DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: {
                    if let myAudioDataFromUrl = try? Data(contentsOf: audioUrl){
                        // after downloading your data you need to save it to your destination url
                        if (try? myAudioDataFromUrl.write(to: destinationUrl, options: [.atomic])) != nil {
                            print("file saved")
                            completion(destinationUrl.absoluteString)
                            self.isDownloading.toggle()
                        } else {
                            print("error saving file")
                            completion("")
                        }
                    }
                })
            }
        }
    }
    
}

extension SereneAudioStreamPlayer {
    public enum Layout {
        case music
        case unguided
        case classCollection
        case unknown
        case intro
    }
}
