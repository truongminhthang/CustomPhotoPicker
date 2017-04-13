//
//  GridViewCell.swift
//  CustomPhotoPicker
//
//  Created by Trương Thắng on 4/12/17.
//  Copyright © 2017 Trương Thắng. All rights reserved.
//

import UIKit

class GridViewCell: UICollectionViewCell {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var livePhotoBadgeImageView: UIImageView!
    
    var representedAssetIdentifier: String!
    
    var thumbnailImage: UIImage! {
        didSet {
            imageView.image = thumbnailImage
        }
    }
    var livePhotoBadgeImage: UIImage! {
        didSet {
            livePhotoBadgeImageView.image = livePhotoBadgeImage
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        livePhotoBadgeImageView.image = nil
        imageView.contentMode = .scaleAspectFill
    }
}
