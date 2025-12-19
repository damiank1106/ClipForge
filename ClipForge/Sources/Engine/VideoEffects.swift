import Foundation
import CoreImage

enum VideoEffects {
    static func apply(filter: EditorFilter?, to image: CIImage) -> CIImage? {
        guard let filter else { return nil }
        switch filter {
        case .none:
            return image
        case .noir:
            return image.applyingFilter("CIPhotoEffectNoir")
        case .chrome:
            return image.applyingFilter("CIPhotoEffectChrome")
        case .instant:
            return image.applyingFilter("CIPhotoEffectInstant")
        case .sepia:
            return image.applyingFilter("CISepiaTone", parameters: ["inputIntensity": 0.9])
        case .bloom:
            return image.applyingFilter("CIBloom", parameters: ["inputIntensity": 0.7, "inputRadius": 8.0])
        case .vivid:
            return image.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.35, "inputContrast": 1.12, "inputBrightness": 0.02])
        case .mono:
            return image.applyingFilter("CIPhotoEffectMono")
        }
    }
}
