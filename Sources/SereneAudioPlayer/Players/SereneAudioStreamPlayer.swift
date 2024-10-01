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
    
    @State var currentSelectedMenu = String()
    
    @ObservedObject public var viewModel: SereneAudioStreamPlayerViewModel
    
    public init(viewModel: SereneAudioStreamPlayerViewModel) {
        self.viewModel = viewModel
    }

    @State var downloaded = false
    @State var disableDownload = false
    
    @State var fadeTimer = Timer.publish(every: 3, on: .current, in: .common).autoconnect()
    @State var fadeInOpacity: Double = 1
    
    @State private var backgroundPlayerOpacity: Double = 0
    
    var likeButtonView: some View {
        Button(action: {
            viewModel.trackFavoritedAction()
        }) {
            
            if viewModel.trackFavorited {
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
            viewModel.playAction()
            fadeInOpacity = 1
        }) {
            
            Image(systemName: viewModel.isPlaying && !viewModel.isFinished ? "pause.fill" : "play.fill")
                .foregroundColor(.white)
                .font(.largeTitle)
                .frame(width: 80, height: 80)
                .background(.white.opacity(0.3))
                .clipShape(Circle())
        }
    }
    
    var backwardButtonView: some View {
        Button(action: {
            viewModel.rewindAction()
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
                KFImage(URL(string: viewModel.track.image ?? ""))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width)
                    .edgesIgnoringSafeArea(.vertical)
                
                // Background Video Player
                
                if viewModel.backgroundPlayer != nil {
                    VideoPlayerView(player: $viewModel.backgroundPlayer, isAudioPlayed: $viewModel.isPlaying) {
                        backgroundPlayerOpacity = 1
                    }
                    .opacity(backgroundPlayerOpacity)
                    .ignoresSafeArea()
                    .disabled(true)
                    
                    VideoPlayerView(player: $viewModel.noisePlayer, isAudioPlayed: $viewModel.isPlaying) { }
                        .opacity(0)
                        .ignoresSafeArea()
                        .disabled(true)
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
                        Text(viewModel.track.title ?? "No track title")
                            .foregroundColor(.white)
                            .font(.custom("Helvetica Neue", size: 32))
                            .fontWeight(.bold)
                            .padding(.bottom, 8)
                            .multilineTextAlignment(.leading)
                        
                        Text(viewModel.track.subtitle ?? "No track subtitle")
                            .foregroundColor(.white)
                            .font(.custom("Helvetica Neue", size: 20))
                            .fontWeight(.medium)
                            .padding(.bottom, 30)
                    }
                    .padding(.horizontal)
                    
                    VStack {
                        ZStack(alignment: .leading) {
                            
                            if viewModel.type == .music {
                                Image(.liveAudio)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Group {
                                    if viewModel.isPlayerDurationMoreThanZero {
                                        SliderView(value: $viewModel.displayTime, in: 0...viewModel.itemDuration) { isScrubStarted in
                                            if isScrubStarted {
                                                viewModel.updateScrub(.scrubStarted)
                                                
                                            } else {
                                                viewModel.updateScrub(.scrubEnded(viewModel.displayTime))
                                                
                                            }
                                        }
                                        .frame(height: 10)
                                    } else {
                                        SliderView(value: $viewModel.displayTime, in: 0...0) { _ in }
                                            .frame(height: 10)
                                    }
                                }
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal)
                        if viewModel.type != .music {
                            HStack {
                                Text(viewModel.displayTimeFormattedText)
                                Spacer()
                                if viewModel.isPlayerDurationMoreThanZero {
                                    Text(viewModel.displayItemDurationFormattedText)
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
                        
                        
                        if viewModel.type == .classCollection {
                            backwardButtonView
                        }
                        
                        Spacer()
                        
                        
                        if viewModel.type == .classCollection {
                            likeButtonView
                        }
                        
                        switch viewModel.type {
                        case .music, .unguided, .intro, .classCollection:
                            KebabMenuView(options: [
                                KebabMenuModel(text: "Share", icon: .share)
                            ], currentSelection: $currentSelectedMenu)
                        case .unknown:
                            Button(action: {
                                let urlString = viewModel.track.streamURL ?? ""
                                
                                let encodedSoundString = urlString.removingPercentEncoding?.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
                                
                                viewModel.downloadAndSaveAudioFile(encodedSoundString!) { (url) in
                                    self.downloaded = true
                                    self.disableDownload = true
                                }
                            }) {
                                
                                if viewModel.isDownloading {
                                    ActivityIndicatorView(isVisible: $viewModel.isDownloading, type: .default)
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
                        viewModel.appearAction()
                    }
                    .alert(isPresented: $viewModel.showingAlert) {
                        Alert(title: Text("No Internet Connection"), message: Text("Please ensure your device is connected to the internet."), dismissButton: .default(Text("Got it!")))
                        
                    }
                    .onChange(of: currentSelectedMenu) { value in
                        switch value {
                        case "Share":
                            viewModel.shareButtonAction()
                        case "Download":
                            break
                        default:
                            break
                        }
                        currentSelectedMenu = ""
                    }
                }
                .opacity(fadeInOpacity)
            }
            .overlay(alignment: .centerLastTextBaseline) {
                playButtonView
            }
            .onTapGesture {
                fadeInOpacity = 1
                fadeTimer = Timer.publish(every: 3, on: .current, in: .common).autoconnect()
            }
            .toolbar(content: {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.destroyAll()
                        viewModel.dismissAction()
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
        .onReceive(fadeTimer) { _ in
            if fadeInOpacity != 0 && viewModel.isPlaying {
                withAnimation {
                    fadeInOpacity = 0
                }
            }
        }
        .onChange(of: viewModel.isFinished) { isFinished in
            if isFinished {
                dismiss()
            }
        }
        .onDisappear {
            viewModel.destroyAll()
        }
        
    }
}

public typealias LayoutType = SereneAudioStreamPlayer.Layout

extension SereneAudioStreamPlayer {
    public enum Layout {
        case music
        case unguided
        case classCollection
        case unknown
        case intro
    }
}
