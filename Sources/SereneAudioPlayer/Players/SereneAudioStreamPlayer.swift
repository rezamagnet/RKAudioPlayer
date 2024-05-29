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
    
    @State var currentSelectedMenu = String()
    
    @State var trackFavourited: Bool = false
    
    @State var player : AVPlayer?
    @State var backgroundPlayer: AVPlayer?
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
    
    @State private var backgroundPlayerItemBufferEmptyObserver: NSKeyValueObservation?
    @State private var backgroundPlayerItemBufferKeepUpObserver: NSKeyValueObservation?
    @State private var backgroundPlayerItemBufferFullObserver: NSKeyValueObservation?
    @State private var backgroundPlayerOpacity: Double = 0
    
    let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
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
            
            if track.favourited == true {
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
                    
                    self.player?.pause()
                    self.playing = false
                } else {
                    
                    if self.finish {
                        
                        self.player?.seek(to: .zero)
                        self.width = 0
                        self.finish = false
                        self.assetCurrentDuration = 0
                    }
                    
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
            timeBackward -= 5
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
                if let backgroundAnimationURL = track.animation.backgroundAnimationURL {
                    VideoPlayer(player: backgroundPlayer)
                        .opacity(backgroundPlayerOpacity)
                        .ignoresSafeArea()
                        .disabled(true)
                        .onAppear {
                            // MARK: - background player handler
                            
                            if let encodedAnimationString = backgroundAnimationURL.removingPercentEncoding?.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
                               let animationURL = URL(string: encodedAnimationString) {
                                
                                backgroundPlayer = AVPlayer(url: animationURL)
                                let volume = Float(track.animation.backgroundVolume ?? 0) / 100
                                backgroundPlayer?.volume = volume
                                
                                NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: backgroundPlayer?.currentItem, queue: .main) { _ in
                                    backgroundPlayer?.seek(to: .zero)
                                    backgroundPlayer?.play()
                                }
                                    
                                backgroundPlayerItemBufferKeepUpObserver = backgroundPlayer?.currentItem?.observe(\AVPlayerItem.isPlaybackLikelyToKeepUp, options: [.new]) { _,_  in
                                    backgroundPlayerOpacity = 1
                                    backgroundPlayer?.playImmediately(atRate: 1)
                                }
                                    
                                backgroundPlayerItemBufferFullObserver = backgroundPlayer?.currentItem?.observe(\AVPlayerItem.isPlaybackBufferFull, options: [.new]) { _,_  in
                                    backgroundPlayerOpacity = 1
                                }
                                
                            }
                        }
                        .onDisappear {
                            backgroundPlayer?.pause()
                            backgroundPlayer = nil
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
                                Text(durationFormatter.string(from: assetDuration)!)
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
                        case .music, .unguided, .classCollection:
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
                        let urlString = self.track.streamURL ?? ""
                        
                        let encodedSoundString = urlString.removingPercentEncoding?.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
                        
                        let url = URL(string: encodedSoundString!)
                        
                        let playerItem = AVPlayerItem(url: url!)
                        
                        self.player = AVPlayer(playerItem: playerItem)
                        
                        self.player?.automaticallyWaitsToMinimizeStalling = false
                        
                        playerItemBufferKeepUpObserver = player?.currentItem?.observe(\AVPlayerItem.isPlaybackLikelyToKeepUp, options: [.new]) { _,_  in
                            assetDuration = playerItem.duration.seconds
                        }
                        
                        
                        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (_) in
                            
                            if self.player?.isPlaying == true {
                                
                                let screen = UIScreen.main.bounds.width - 30
                                
                                Task {
                                    if let seconds = try await self.player?.currentItem?.asset.load(.duration).seconds {
                                        let value = (self.player?.currentItem!.currentTime().seconds ?? 0) / seconds
                                        self.width = screen * CGFloat(value)
                                        
                                        assetCurrentDuration += 1
                                        if getPercentComplete(currentDuration: assetCurrentDuration, totalDuration: assetDuration) > 75 {
                                            isSeen = true
                                        }
                                    }
                                }
                            }
                        }

                        NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: self.player?.currentItem, queue: .main) { _ in
                            if layout == .music {
                                self.player?.seek(to: .zero)
                                self.player?.play()
                            } else {
                                self.finish = true
                                self.onFinish()
                            }
                        }
                        
                        self.setupRemoteTransportControls()
                        Task {
                            do {
                                try await self.setupNowPlaying(track: self.track)
                            } catch {
                                
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
                        backgroundPlayer?.pause()
                        player?.pause()
                        
                        backgroundPlayer = nil
                        player = nil
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
            print("Play command - is playing: \(self.player?.isPlaying)")
            if !(self.player?.isPlaying ?? false) {
                self.player?.play()
                return .success
            }
            return .commandFailed
        }
        
        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [self] event in
            print("Pause command - is playing: \(self.player?.isPlaying)")
            if self.player?.isPlaying == true {
                self.player?.pause()
                return .success
            }
            return .commandFailed
        }
        
    }
    
    func setupNowPlaying(track: Track) async throws {
        // Define Now Playing Info
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        
        if let image = UIImage(named: track.image ?? "") {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { size in
                return image
            }
        }
        
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime().seconds
        
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = try await self.player?.currentItem?.asset.load(.duration).seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate
        
        // Set the metadata
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
    }
}
