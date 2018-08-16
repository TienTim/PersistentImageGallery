//
//  ImageGalleryCollectionViewCell.swift
//  ImageGallery
//
//  Created by Tien Do on 8/7/18.
//  Copyright © 2018 tiendo. All rights reserved.
//

import UIKit

class ImageGalleryCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    var url: URL!
    
}
