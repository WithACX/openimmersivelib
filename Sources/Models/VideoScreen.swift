//
//  VideoScreen.swift
//  OpenImmersive
//
//  Created by Anthony Maës (Acute Immersive) on 1/17/25.
//

import RealityKit
import Observation

/// Manages `Entity` with the sphere/half-sphere or native player onto which the video is projected.
@MainActor
public class VideoScreen {
    /// The `Entity` containing the sphere or flat plane onto which the video is projected.
    public let entity: Entity = Entity()
    private let backdropEntity: ModelEntity = {
        let material = SimpleMaterial(color: .black, isMetallic: false)
        let entity = ModelEntity(mesh: .generatePlane(width: 1, height: 1), materials: [material])
        entity.name = "VideoScreen Backdrop"
        entity.isEnabled = false
        entity.transform = Transform(
            scale: .one,
            rotation: .init(),
            translation: [0, 0, -0.1]
        )
        return entity
    }()
    
    /// Public initializer for visibility.
    public init() {
        entity.addChild(backdropEntity)
    }
    
    /// The transform to apply to the native VideoPlayerComponent when the projection is a simple rectangle.
    private static let rectangularScreenTransform = Transform(
        scale: .init(x: 100, y: 100, z: -100),
        rotation: .init(),
        translation: .init(x: 0, y: 0, z: -200))
    
    /// Updates the video screen mesh with values from a VideoPlayer instance to resize it and start displaying its video media.
    /// - Parameters:
    ///   - videoPlayer: the VideoPlayer instance
    ///   - projection: the projection type of the media
    ///   - width: the absolute width/scale of the screen (default: 100.0, matching rectangularScreenTransform)
    public func update(source videoPlayer: VideoPlayer, projection: StreamModel.Projection, width: Float = 100.0) {
        switch projection {
        case .equirectangular(fieldOfView: _, force: _):
            // updateSphere() must be called only once to prevent creating multiple VideoMaterial instances
            withObservationTracking {
                _ = videoPlayer.aspectRatio
            } onChange: {
                Task { @MainActor in
                    self.updateSphere(videoPlayer, width: width)
                }
            }
        
        case .rectangular:
            let customTransform = Transform(
                scale: .init(x: width, y: width, z: -width),
                rotation: .init(),
                translation: .init(x: 0, y: 0, z: -200))
            self.updateNativePlayer(videoPlayer, transform: customTransform)
            
        case .appleImmersive:
            // the Apple Immersive Video entity should always use the identity transform
            self.updateNativePlayer(videoPlayer)
        }
        updateBackdrop(for: projection, width: width)
    }
    
    /// Programmatically generates the sphere or half-sphere entity with a VideoMaterial onto which the video is projected.
    /// - Parameters:
    ///   - videoPlayer:the VideoPlayer instance
    ///   - width: the absolute scale to apply to the sphere
    private func updateSphere(_ videoPlayer: VideoPlayer, width: Float = 100.0) {
        let (mesh, transform) = VideoTools.makeVideoMesh(
            hFov: videoPlayer.horizontalFieldOfView,
            vFov: videoPlayer.verticalFieldOfView
        )
        entity.name = "VideoScreen (Sphere)"
        entity.components[VideoPlayerComponent.self] = nil
        entity.components[ModelComponent.self] = ModelComponent(
            mesh: mesh,
            materials: [VideoMaterial(avPlayer: videoPlayer.player)]
        )
        // Apply width scaling to the transform
        var scaledTransform = transform
        let scaleFactor = width / 100.0  // Normalize against default
        scaledTransform.scale *= scaleFactor
        entity.transform = scaledTransform
    }
    
    /// Sets up the entity with a VideoPlayerComponent that renders the video natively.
    /// - Parameters:
    ///   - videoPlayer:the VideoPlayer instance
    ///   - transform: the position of the entity (default identity)
    private func updateNativePlayer(_ videoPlayer: VideoPlayer, transform: Transform = .identity) {
        let videoPlayerComponent = {
            var videoPlayerComponent = VideoPlayerComponent(avPlayer: videoPlayer.player)
            videoPlayerComponent.desiredViewingMode = .stereo
            videoPlayerComponent.desiredImmersiveViewingMode = .full
            return videoPlayerComponent
        }()
        entity.name = "VideoScreen (Native Player)"
        entity.components[ModelComponent.self] = nil
        entity.components[VideoPlayerComponent.self] = videoPlayerComponent
        entity.transform = transform
    }
    
    private func updateBackdrop(for projection: StreamModel.Projection, width: Float) {
        let shouldShowBackdrop: Bool = {
            if case .rectangular = projection { return true }
            return false
        }()
        backdropEntity.isEnabled = shouldShowBackdrop
        guard shouldShowBackdrop else { return }
        let baseWidth = max(width, 0.1)
        backdropEntity.transform = Transform(
            scale: [baseWidth * 1.5, baseWidth * 1.5, max(baseWidth * 0.01, 0.01)],
            rotation: .init(),
            translation: [0, 0, baseWidth * 0.05]
        )
    }
}
