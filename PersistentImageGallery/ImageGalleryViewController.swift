//
//  ImageGalleryViewController.swift
//  ImageGallery
//
//  Created by Tien Do on 8/7/18.
//  Copyright © 2018 tiendo. All rights reserved.
//

import UIKit

var defaults = UserDefaults.standard

class ImageGalleryViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDropDelegate, UICollectionViewDragDelegate, UIDropInteractionDelegate, UICollectionViewDelegateFlowLayout {
    
    //MARK: - Model
    
    var imageGallery: ImageGallery? {
        get {
            var images = [ImageGallery.Image]()
            imageInfos.forEach {
                guard let url = $0.url, let ratio = $0.ratio else { return }
                images.append(ImageGallery.Image(url: url, ratio: Float(ratio)))
            }
            return ImageGallery(images: images)
        }
        set {
            imageInfos.removeAll()
            newValue?.images.forEach { imageInfos.append(($0.url, CGFloat($0.ratio))) }
            collectionView.reloadData()
        }
    }
    
    //MARK: - Document Handling
    
    var documents: ImageGalleryDocument?
    
    func documentChanged() {
        documents?.imageGallery = imageGallery
        if documents?.imageGallery != nil {
            if let json = documents?.imageGallery?.json {
                if let jsonString = String(data: json, encoding: .utf8) {
                    print(jsonString)
                }
            }
            documents?.thumbnail = firstImage
            documents?.updateChangeCount(.done)
        }
    }
    
    var firstImage: UIImage?

    @IBAction func close(_ sender: UIBarButtonItem) {
        dismiss(animated: true) {
            self.documents?.close()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        documents?.open { success in
            if success {
                self.title = self.documents?.localizedName
                self.imageGallery = self.documents?.imageGallery
            }
        }
    }
    
    //MARK: - Storyboard
    
    @IBOutlet weak var dropZone: UIView! {
        didSet {
            dropZone.addInteraction(UIDropInteraction(delegate: self))
        }
    }
    
    var imageInfos = [(url: URL?, ratio: CGFloat?)]()
    
    var cellWidthScale: CGFloat = 1  {
        didSet {
            flowLayout?.invalidateLayout()
        }
    }

    private var flowLayout: UICollectionViewFlowLayout? {
        return collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    }
    
    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView.delegate = self
            collectionView.dataSource = self
            collectionView.dragDelegate = self
            collectionView.dropDelegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(adjustCellWidth(byHandlingGestureRecognizedBy:)))
        view.addGestureRecognizer(pinchGesture)
        let cache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 1024 * 1024, diskPath: nil)
        URLCache.shared = cache
    }
    
    @objc func adjustCellWidth(byHandlingGestureRecognizedBy recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .changed, .ended:
            cellWidthScale *= recognizer.scale
            recognizer.scale = 1.0
        default:
            break
        }
    }    

    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageInfos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CollectionCell", for: indexPath) as! ImageGalleryCollectionViewCell
        cell.spinner.startAnimating()
        let imageInfo = imageInfos[indexPath.item]
        DispatchQueue.global(qos: .userInitiated).async {
            var cacheResponse = CachedURLResponse()
            let task = URLSession.shared.dataTask(with: imageInfo.url!) { data, response, error in
                cacheResponse = CachedURLResponse(response: response!, data: data!)
            }
            URLCache.shared.storeCachedResponse(cacheResponse, for: task)
            if let data = try? Data(contentsOf: imageInfo.url!) {
                DispatchQueue.main.async {
                    cell.spinner.stopAnimating()
                    let image = UIImage(data: data)
                    cell.imageView.image = image
                    if indexPath.item == 0 {
                        self.firstImage = image
                    }
                    cell.url = imageInfo.url
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let itemHeight = 120 * cellWidthScale * (imageInfos[indexPath.item].ratio ?? 1.0)
        return CGSize(width: 120 * cellWidthScale, height: itemHeight)
    }
    
    //MARK: - UICollectionViewDragDelegate
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = collectionView
        return dragItems(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        return dragItems(at: indexPath)
    }
    
    private func dragItems(at indexPath: IndexPath) -> [UIDragItem] {
        if let url = (collectionView?.cellForItem(at: indexPath) as? ImageGalleryCollectionViewCell)?.url {
            let dragItem = UIDragItem(itemProvider: NSItemProvider(object: url as NSItemProviderWriting))
            dragItem.localObject = url
            return [dragItem]
        } else {
            return []
        }
    }
    
    //MARK: - UICollectionViewDropDelegate
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: URL.self)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        return UICollectionViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(item: 0, section: 0)
        for item in coordinator.items {
            if let sourceIndexPath = item.sourceIndexPath {
                if let _ = item.dragItem.localObject as? URL {
                    collectionView.performBatchUpdates({
                        let tuple = imageInfos.remove(at: sourceIndexPath.item)
                        imageInfos.insert(tuple, at: destinationIndexPath.item)
                        collectionView.deleteItems(at: [sourceIndexPath])
                        collectionView.insertItems(at: [destinationIndexPath])
                    })
                    documentChanged()
                    coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
                }
            } else {
                guard URLCache.shared.currentMemoryUsage < 50 * 1024 else {     // reasonable limit file system usage is 50kB
                    let alert = UIAlertController(title: "File system usage overload", message: nil, preferredStyle: .alert)
                    let action = UIAlertAction(title: "OK", style: .default)
                    alert.addAction(action)
                    present(alert, animated: true)
                    print("\(URLCache.shared.currentMemoryUsage): Usage overload")
                    return
                }
                print("\(URLCache.shared.currentMemoryUsage): Cache usage")
                let placeHolderContext = coordinator.drop(
                    item.dragItem,
                    to: UICollectionViewDropPlaceholder(insertionIndexPath: destinationIndexPath, reuseIdentifier: "DropPlaceHolderCell")
                )
                var ratio: CGFloat = 0
                item.dragItem.itemProvider.loadObject(ofClass: UIImage.self) { (provider, error) in
                    if let image = provider as? UIImage {
                        ratio = image.size.height / image.size.width
                    }
                }
                item.dragItem.itemProvider.loadObject(ofClass: NSURL.self) { (provider, error) in
                    DispatchQueue.main.async {
                        if let url = provider as? URL {
                            let imageURL = url.imageURL
                            placeHolderContext.commitInsertion(dataSourceUpdates: { (insertionIndexPath) in
                                self.imageInfos.insert((imageURL, ratio), at: insertionIndexPath.item)
                            })
                            self.documentChanged()
                            self.collectionView.reloadData()
                        } else {
                            placeHolderContext.deletePlaceholder()
                        }
                    }
                }
            }
        }
    }
    
    //MARK: - UIDropInteractionDelegate
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSURL.self) && session.canLoadObjects(ofClass: UIImage.self)
    }
    
    //MARK: - Collection view delegate
    
    var url: URL?
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let item = collectionView.cellForItem(at: indexPath) as? ImageGalleryCollectionViewCell {
            url = item.url
            performSegue(withIdentifier: "ShowImage", sender: item)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let imageVC = segue.destination as? ImageViewController {
            imageVC.imageURL = url!
        }
    }
    
}
