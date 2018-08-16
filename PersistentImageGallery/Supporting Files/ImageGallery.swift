//
//  ImageGallery.swift
//  PersistentImageGallery
//
//  Created by Tien Do on 8/16/18.
//  Copyright © 2018 tiendo. All rights reserved.
//

import Foundation

struct ImageGallery: Codable {
    
    var images = [Image]()
    
    struct Image: Codable {
        var url: URL
        var ratio: Float
        
        init(url: URL, ratio: Float) {
            self.url = url
            self.ratio = ratio
        }
    }

    init?(json: Data) {
        if let newValue = try? JSONDecoder().decode(ImageGallery.self, from: json) {
            self = newValue
        } else {
            return nil
        }
    }
    
    var json: Data? {
        return try? JSONEncoder().encode(self)
    }
    
    init(images: [Image]) {
        self.images = images
    }

}
