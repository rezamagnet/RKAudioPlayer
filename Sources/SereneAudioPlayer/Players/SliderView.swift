//
//  SliderView.swift
//  SwiftUIAVPlayer
//
//  Created by Fatemeh Najafi Moghadam on 9/3/24.
//  Copyright © 2024 Jon Gary. All rights reserved.
//

import SwiftUI

@available(iOS 16.0, *)
struct SliderView: View {
    @Binding private var value: Double
    @State private var lastCoordinateValue: CGFloat = 0.0
    private var sliderRange: ClosedRange<Double>
    private var onEditingChanged: (Bool) -> Void
    
    
    init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 1...100,
        onEditingChanged: @escaping (Bool) -> Void
    ) {
        self._value = value
        self.sliderRange = range
        self.onEditingChanged = onEditingChanged
    }
    
    enum Constants {
        static let height: CGFloat = 4
    }
    
    var body: some View {
        GeometryReader { proxy in
            let thumbSize = proxy.size.height * 1.5
            let radius = proxy.size.height * 0.5
            let minValue: CGFloat = .zero
            let maxValue = proxy.size.width - thumbSize
            
            let scaleFactor = (maxValue - minValue) / (sliderRange.upperBound - sliderRange.lowerBound)
            let lower = sliderRange.lowerBound
            let sliderVal = (self.value - lower) * scaleFactor + minValue
            
            ZStack {
                Group {
                    
                    RoundedRectangle(cornerRadius: radius)
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(height: Constants.height)
                    
                    HStack {
                        Rectangle()
                            .clipShape(
                                .rect(
                                    topLeadingRadius: radius,
                                    bottomLeadingRadius: radius,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 0
                                )
                            )
                            .frame(width: sliderVal, height: Constants.height)
                        Spacer()
                    }
                }
                
                HStack {
                    Circle()
                        .shadow(radius: 3)
                        .frame(width: thumbSize, height: thumbSize)
                        .offset(x: sliderVal)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded({ _ in
                                    onEditingChanged(false)
                                })
                                .onChanged { v in
                                    if (abs(v.translation.width) < 0.1) {
                                        self.lastCoordinateValue = sliderVal
                                    }
                                    if v.translation.width > 0 {
                                        let nextCoordinateValue = min(maxValue, self.lastCoordinateValue + v.translation.width)
                                        self.value = ((nextCoordinateValue - minValue) / scaleFactor)  + lower
                                    } else {
                                        let nextCoordinateValue = max(minValue, self.lastCoordinateValue + v.translation.width)
                                        self.value = ((nextCoordinateValue - minValue) / scaleFactor) + lower
                                    }
                                    
                                    onEditingChanged(true)
                                }
                        )
                    Spacer()
                }
            }
        }
    }
}
