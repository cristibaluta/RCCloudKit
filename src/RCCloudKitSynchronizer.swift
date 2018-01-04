//
//  Created by Cristian Baluta on 14/12/2017.
//  Copyright © 2017 Baluta Cristian. All rights reserved.
//

import Foundation
import CoreData

@objc class RCCloudKitSynchronizer: NSObject {
    
    fileprivate let moc: NSManagedObjectContext!
    fileprivate let ck: RCCloudKit!
    fileprivate var toUpload = [NSManagedObject]()
    fileprivate var toDelete = [NSManagedObject]()
    fileprivate var isSavingFromCK = false
    
    init(moc: NSManagedObjectContext, ck: RCCloudKit) {
        self.moc = moc
        self.ck = ck
        super.init()
        NotificationCenter.default.addObserver(self, 
                                               selector: #selector(self.willSave(notification:)), 
                                               name: .NSManagedObjectContextWillSave, 
                                               object: nil)
    }
    
    func start (_ completion: @escaping ((_ hasIncomingChanges: Bool) -> Void)) {
        
        // Backup to CloudKit existing unsynced objects
        toUpload = ck.dataSource.managedObjectsToUpload()
        toDelete = ck.dataSource.managedObjectsToDelete()
        
        print("Found objs to upload: \(toUpload.count)")
        print("Found objs to delete: \(toDelete.count)")
        
        startUpload { (success) in
            
            self.startDownload { (hasIncomingChanges) in
                
                if self.moc.hasChanges {
                    self.isSavingFromCK = true
                    try? self.moc.save()
                    self.isSavingFromCK = false
                }
                print("Sync finished")
                completion(hasIncomingChanges)
            }
        }
    }
    
    func startUpload (_ completion: @escaping ((_ success: Bool) -> Void)) {
        
        uploadNextObj { (success) in
            print("Upload finished")
            completion(success)
        }
    }
    
    func startDownload (_ completion: @escaping ((_ hasIncomingChanges: Bool) -> Void)) {
        
        ck.queryUpdates() { changed, deletedIds, error in
            print("Found clipboards to download \(changed.count)")
            print("Found clipboards to delete \(deletedIds.count)")
            completion(changed.count > 0 || deletedIds.count > 0)
        }
    }
    
    fileprivate func uploadNextObj (_ completion: @escaping ((_ success: Bool) -> Void)) {
        
        if let c = toUpload.first {
            toUpload.remove(at: 0)
            ck.save(c) { (localObj) in
                self.uploadNextObj(completion)
            }
        } else if let c = toDelete.first {
            toDelete.remove(at: 0)
            ck.delete(c, completion: { success in
                self.uploadNextObj(completion)                
            })
        } else {
            completion(true)
        }
    }
}

extension RCCloudKitSynchronizer {
    
    @objc fileprivate func willSave (notification: Notification) {
        
        guard !isSavingFromCK else {
            // After you save 
            print("Prevent saving to CK the same objects that were saved from CK")
            return
        }
        guard let context = notification.object as? NSManagedObjectContext else {
            return
        }
        let inserted = context.insertedObjects
        let updated = context.updatedObjects
        print("inserted \(inserted)")
        print("updated \(updated)")
        
        toUpload += Array(inserted) + Array(updated)
        toUpload = toUpload.flatMap { $0.changedValues().count > 0 ? $0 : nil }
        if toUpload.count > 0 {
            startUpload({ (success) in
                
            })
        }
    }
}
