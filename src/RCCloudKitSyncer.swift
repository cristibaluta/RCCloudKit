//
//  Created by Cristian Baluta on 14/12/2017.
//  Copyright © 2017 Baluta Cristian. All rights reserved.
//

import Foundation
import CoreData

@objc class RCCloudKitSyncer: NSObject {
    
    let moc: NSManagedObjectContext!
    fileprivate let ck: RCCloudKit!
    fileprivate var toSave = [NSManagedObject]()
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
        toSave = objsToSave()
        toSave = objsToDelete()
        print("Found clipboards to upload: \(toSave.count)")
        print("Found clipboards to delete: \(toDelete.count)")
        
        self.syncNextObj { (success) in
            self.getLatestServerChanges({ (hasIncomingChanges) in
                self.isSavingFromCK = true
                try? self.moc.save()
                self.isSavingFromCK = false
                UserDefaults.standard.lastSyncDate = Date()
                completion(hasIncomingChanges)
            })
        }
    }
    
    fileprivate func syncNextObj (_ completion: @escaping ((_ success: Bool) -> Void)) {
        
        if let c = toSave.first {
            toSave.remove(at: 0)
            ck.save(c) { (uploadedClipboard) in
                // After task was saved to server update it to local datastore
                self.syncNextObj(completion)
            }
        } else if let c = toDelete.first {
            toDelete.remove(at: 0)
            ck.delete(c, completion: { success in
                self.syncNextObj(completion)                
            })
        } else {
            completion(true)
        }
    }
    
    func getLatestServerChanges (_ completion: @escaping ((_ hasIncomingChanges: Bool) -> Void)) {
        
        ck.queryUpdates() { changed, deletedIds, error in
            print("Found clipboards to download \(changed.count)")
            print("Found clipboards to delete \(deletedIds.count)")
            completion(changed.count > 0 || deletedIds.count > 0)
        }
    }
}

extension RCCloudKitSyncer {
    
    @objc fileprivate func willSave(notification: Notification) {
        
        guard !isSavingFromCK else {
            print("Preventing from saving to CK the same objects that were saved from CK")
            return
        }
        guard let context = notification.object as? NSManagedObjectContext else {
            return
        }
        let inserted = context.insertedObjects
        let updated = context.updatedObjects
        print("inserted \(inserted)")
        print("updated \(updated)")
        
        toSave += inserted
        if toSave.count > 0 {
            start({ (hasChanges) in
                print("sync fin")
            })
        }
    }
}
