//
//  ArtworkImageBaseView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI

@available(iOS 14, tvOS 14, *)
struct ArtworkImageBaseView: SwiftUI.View {

    var artwork: SwiftImage?
    var gameTitle: String
    var boxartAspectRatio: PVGameBoxArtAspectRatio

    init(artwork: SwiftImage?, gameTitle: String, boxartAspectRatio: PVGameBoxArtAspectRatio) {
        self.artwork = artwork
        self.gameTitle = gameTitle
        self.boxartAspectRatio = boxartAspectRatio
    }

    var body: some SwiftUI.View {
        if let artwork = artwork {
            SwiftUI.Image(uiImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            SwiftUI.Image(uiImage: UIImage.missingArtworkImage(gameTitle: gameTitle, ratio: boxartAspectRatio.rawValue))
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}