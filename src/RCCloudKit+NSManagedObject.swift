//
//  Created by Cristian Baluta on 02/04/2017.
//  Copyright © 2017 Imagin soft. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

extension RCCloudKit {
    
    func queryUpdates (_ completion: @escaping ([NSManagedObject], [String], NSError?) -> Void) {
        
        let changeToken = UserDefaults.standard.serverChangeToken
        
        fetchChangedRecords(token: changeToken, completion: { (changedRecords, deletedRecordsIds) in
            
            // Save CKRecord to CoreData
            let objects = self.objs(from: changedRecords)
            
            // Delete CoreData objects permanently
            let deletedRecordsNames: [String] = deletedRecordsIds.map { $0.recordName }
            for recordID in deletedRecordsIds {
                self.delegate.delete(with: recordID)
            }
            completion(objects, deletedRecordsNames, nil)
        })
    }
    
    func save (_ obj: NSManagedObject, completion: @escaping ((_ updatedObj: NSManagedObject) -> Void)) {
        rccloudkitprint("1. Save to cloudkit \(obj)")
        
        guard let zone = self.customZone, let privateDB = self.privateDB, let entityName = obj.entity.name else {
            rccloudkitprint("Can't save, not logged in to iCloud or zone not ready")
            completion(obj)
            return
        }
        
        // Query CKRecord from server
        fetchCKRecord(of: obj) { record in
            
            var record: CKRecord? = record
            if record == nil {
                rccloudkitprint("Record not found on server, create it now")
                let recordID = CKRecord.ID(zoneID: zone.zoneID)
                record = CKRecord(recordType: entityName, recordID: recordID)
            }
            record = self.updateRecord(record!, with: obj)
            
            privateDB.save(record!, completionHandler: { savedRecord, error in
                
                if let record = savedRecord {
                    let obj = self.delegate.save(record: record, in: obj)
                    // It is essential to save the context now, can't rely on the user doing it manually
                    // Otherwise you can end up with duplicates if the object was saved through save method instead the full sync
                    if self.moc.hasChanges {
                        try? self.moc.save()
                        rccloudkitprint("Save context: \(String(describing: self.moc))")
                    }
                    rccloudkitprint("2. Save end to cloudkit and updated locally: \(obj)")
                    completion(obj)
                } else {
                    completion(obj)
                }
            })
        }
    }
    
    func delete (_ obj: NSManagedObject, completion: @escaping ((_ success: Bool) -> Void)) {
        
        rccloudkitprint("Delete from CK \(obj)")
        guard let _ = self.customZone, let privateDB = self.privateDB else {
            rccloudkitprint("Not logged in or zone not created")
            completion(false)
            return
        }
        guard let recordID = dataSource.recordID(from: obj) else {
            rccloudkitprint("Local obj is missing a recordID, means it was never uploaded to CK")
            completion(true)// The object is not yet uploaded to CK, means we can consider it was deleted with success from CK
            return
        }
        privateDB.delete(withRecordID: recordID, completionHandler: { (recordName, error) in
            rccloudkitprint("Deleted from ck with recordName: \(String(describing: recordName)), error: \(String(describing: error))")
            let success = error == nil
            completion(success)
        })
    }
}

extension RCCloudKit {
    
    func fetchCKRecord (of obj: NSManagedObject, completion: @escaping ((_ record: CKRecord?) -> Void)) {
        
        guard let privateDB = self.privateDB else {
            rccloudkitprint("Not logged in or zone not created")
            completion(nil)
            return
        }
        guard let recordID = obj.value(forKey: "recordID") as? CKRecord.ID else {
            completion(nil)
            return
        }
        
        privateDB.fetch(withRecordID: recordID) { (record, error) in
            
            if let record = record {
                completion(record)
            } else {
                completion(nil)
            }
        }
    }
    
    private func objs (from records: [CKRecord]) -> [NSManagedObject] {
        return records.map { self.obj(from: $0) }
    }
    
    private func obj (from record: CKRecord) -> NSManagedObject {
        
        let entityName = record.recordType
        var obj: NSManagedObject? = dataSource.managedObject(from: record)
        if obj == nil {
            rccloudkitprint("NSManagedObject for recordName \(record.recordID.recordName) not found, creating one now")
            obj = NSEntityDescription.insertNewObject(forEntityName: entityName, into: moc)
        }
        obj = updateObj(obj!, with: record)
        
        return obj!
    }
    
    private func updateObj (_ obj: NSManagedObject, with record: CKRecord) -> NSManagedObject {
        
        for key in record.allKeys() {
            obj.setValue(record[key], forKey: key)
        }
        return delegate.save(record: record, in: obj)
    }
    
    private func updateRecord (_ record: CKRecord, with managedObject: NSManagedObject) -> CKRecord {
        
        for (name, _) in  managedObject.entity.attributesByName {
            
            guard name != "recordID" else {
                // RecordID is a reserved key name
                continue
            }
            record[name] = managedObject.value(forKey: name) as? CKRecordValue
        }
        
        return record
    }
}
