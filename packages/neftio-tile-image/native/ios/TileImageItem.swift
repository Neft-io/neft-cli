import UIKit
import AVKit
import AVFoundation

extension Extension.TileImage {
    class TileImageItem: NativeItem {
        override class var name: String { return "TileImage" }

        override class func register() {
            onCreate() {
                return TileImageItem()
            }

            onSet("source") {
                (item: TileImageItem, val: String) in
                item.setSource(val: val)
            }

            onSet("resolution") {
                (item: TileImageItem, val: CGFloat) in
                item.resolution = val
            }
        }

        var source: String?
        var resolution: CGFloat = 1

        init() {
            super.init(itemView: UIView())
        }

        func setSource(val: String) {
            self.source = val
            Image.getImageFromSource(val) { (img: UIImage?) in
                guard self.source == val else { return }
                if img == nil {
                    self.itemView.backgroundColor = nil
                    return
                }
                let scaledImg = UIImage(
                    cgImage: img!.cgImage!,
                    scale: self.resolution,
                    orientation: UIImage.Orientation.up
                )
                self.itemView.backgroundColor = UIColor(patternImage: scaledImg)
            }
        }
    }
}
