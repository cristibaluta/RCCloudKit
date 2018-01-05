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
    
    init(moc: NSManagedObjectContext, ck: RCCloudKit) {
        self.moc = moc
        self.ck = ck
        super.init()
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
                    try? self.moc.save()
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
            print("Found objs to save from the cloud \(changed.count)")
            print("Found objs to delete from the cloud \(deletedIds.count)")
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
