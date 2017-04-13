//
//  CollectionViewController.swift
//  CustomPhotoPicker
//
//  Created by Trương Thắng on 4/12/17.
//  Copyright © 2017 Trương Thắng. All rights reserved.
//

import UIKit
import Photos
import PhotosUI

class AssetGridViewController: UICollectionViewController {

    var fetchResult: PHFetchResult<PHAsset>!
    var assetCollection: PHAssetCollection!
    
    
    fileprivate let imageManager = PHCachingImageManager()
    fileprivate var _itemSize: CGSize? {
        didSet {
            guard _itemSize != nil else {return}
            let flowLayout = (collectionViewLayout as! UICollectionViewFlowLayout)
            flowLayout.itemSize = _itemSize!
            flowLayout.minimumLineSpacing = CollectionViewLayout.minimumInteritemSpacing
            flowLayout.minimumInteritemSpacing = CollectionViewLayout.minimumInteritemSpacing
            
            let scale = UIScreen.main.scale
            thumbnailSize = (_itemSize ?? CGSize.zero) * scale


        }
    }
    
    struct CollectionViewLayout {
        
        static var numberOfItemInRow : CGFloat {
            let isPortrait = UIScreen.main.bounds.width < UIScreen.main.bounds.height
            return isPortrait ? 4.0 : 6.0
        }
        static let edgeInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        static var edgeInsetLeftAndRight : CGFloat {
            return edgeInset.left + edgeInset.right
        }
        
        static let minimumInteritemSpacing : CGFloat = 1
    
        static var totalInteritemSpacing : CGFloat {
            return (numberOfItemInRow - 1) * minimumInteritemSpacing
        }
        
        static var itemSize : CGSize {
            let bounds =  UIScreen.main.bounds
            let size = (bounds.width - edgeInsetLeftAndRight - totalInteritemSpacing) / numberOfItemInRow
            return CGSize(width: size, height: size)
            
        }
    }
    
    var itemSize: CGSize {
        set {
            _itemSize = newValue
        }
        get {
            if _itemSize == nil {
                _itemSize = CollectionViewLayout.itemSize
            }
            return _itemSize ?? CGSize.zero
        }
    }
    
    private var thumbnailSize = CGSize.zero
    fileprivate var previousPreheatRect = CGRect.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        PHPhotoLibrary.shared().register(self)
        // If we get here without a segue, it's because we're visible at app launch,
        // so match the behavior of segue from the default "All Photos" view.
        if fetchResult == nil {
            let allPhotosOptions = PHFetchOptions()
            allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchResult = PHAsset.fetchAssets(with: allPhotosOptions)
        }
        registerNotification()
    }
    
    func registerNotification() {
        NotificationCenter.default.addObserver(self, selector: #selector(deviceDidRotate), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        PHPhotoLibrary.shared().unregisterChangeObserver(self)

    }
    func deviceDidRotate(notification: NSNotification) {
        resetItemSize()
    }
   
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetItemSize()
    }
    
    func resetItemSize() {
        _itemSize = nil
        _ = itemSize
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResult.count + 1
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Dequeue a GridViewCell.
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: GridViewCell.self), for: indexPath) as? GridViewCell
            else { fatalError("unexpected cell in collection view") }

        if indexPath.item == 0 {
            cell.thumbnailImage = #imageLiteral(resourceName: "Compact Camera_ff00ff_100")
            cell.imageView.contentMode = .center
        } else {
            let indexPathItem = indexPath.item - 1
            let asset = fetchResult.object(at: indexPathItem)
            // Add a badge to the cell if the PHAsset represents a Live Photo.
            if asset.mediaSubtypes.contains(.photoLive) {
                cell.livePhotoBadgeImage = PHLivePhotoView.livePhotoBadgeImage(options: .overContent)
            }
            // Request an image for the asset from the PHCachingImageManager.
            cell.representedAssetIdentifier = asset.localIdentifier
            imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil, resultHandler: { image, _ in
                // The cell may have been recycled by the time this handler gets called;
                // set the cell's thumbnail image only if it's still showing the same asset.
                if cell.representedAssetIdentifier == asset.localIdentifier {
                    cell.thumbnailImage = image
                }
            })
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == 0 {
            takePhoto()
        }
    }
}

// MARK: PHPhotoLibraryChangeObserver
extension AssetGridViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        
        guard let changes = changeInstance.changeDetails(for: fetchResult)
            else { return }
        
        // Change notifications may be made on a background queue. Re-dispatch to the
        // main queue before acting on the change as we'll be updating the UI.
        DispatchQueue.main.sync {
            // Hang on to the new fetch result.
            fetchResult = changes.fetchResultAfterChanges
            if changes.hasIncrementalChanges {
                // If we have incremental diffs, animate them in the collection view.
                guard let collectionView = self.collectionView else { fatalError() }
                collectionView.performBatchUpdates({
                    // For indexes to make sense, updates must be in this order:
                    // delete, insert, reload, move
                    if let removed = changes.removedIndexes, removed.count > 0 {
                        collectionView.deleteItems(at: removed.map({ IndexPath(item: $0 - 1, section: 0) }))
                    }
                    if let inserted = changes.insertedIndexes, inserted.count > 0 {
                        collectionView.insertItems(at: inserted.map({ IndexPath(item: $0 + 1, section: 0) }))
                    }
                    if let changed = changes.changedIndexes, changed.count > 0 {
                        collectionView.reloadItems(at: changed.map({ IndexPath(item: $0, section: 0) }))
                    }
                    changes.enumerateMoves { fromIndex, toIndex in
                        collectionView.moveItem(at: IndexPath(item: fromIndex, section: 0),
                                                to: IndexPath(item: toIndex, section: 0))
                    }
                })
            } else {
                // Reload the collection view if incremental diffs are not available.
                collectionView!.reloadData()
            }
        }
    }
}

/* add to info.plist

 */

// MARK: - UIImagePickerControllerDelegate

extension AssetGridViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        // Dismiss the picker if the user canceled.
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let chosenImage = info[UIImagePickerControllerEditedImage] as? UIImage //2
        saveImage(image: chosenImage!)
        dismiss(animated:true, completion: nil) //5
    }
    
    func takePhoto() {
        unowned let weakself = self
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = weakself as UIImagePickerControllerDelegate & UINavigationControllerDelegate
            imagePicker.sourceType = UIImagePickerControllerSourceType.camera;
            imagePicker.allowsEditing = true
            weakself.present(imagePicker, animated: true, completion: nil)
        } else {
            
        }
    }
    
    func saveImage(image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { (success, error) in
            
        })
    }

}

// MARK: - <#Mark#>

extension CGSize {
    static func * (size: CGSize, factory: CGFloat) -> CGSize {
        return CGSize(width: size.width * factory, height: size.height * factory)
    }
}
