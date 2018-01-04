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
            for recordId in deletedRecordsIds {
                self.delegate.delete(with: recordId)
            }
            
            DispatchQueue.main.async {
                completion(objects, deletedRecordsNames, nil)
            }
        })
    }
    
    func save (_ obj: NSManagedObject, completion: @escaping ((_ obj: NSManagedObject) -> Void)) {
        print(">>>>> 1. Save to cloudkit \(obj)")
        
        guard let zone = self.customZone, let privateDB = self.privateDB, let entityName = obj.entity.name else {
            print("Can't save, not logged in to iCloud or zone not ready")
            completion(obj)
            return
        }
        // The changed values will be lost due to unsync operations
        let changedValues = obj.changedValues()
        print(obj.changedValues())
        
        // Query from server if exists
        fetchCKRecord(of: obj) { (record) in
            
            var record: CKRecord? = record
            if record == nil {
                print("Record not found on server, create it now:")
                record = CKRecord(recordType: entityName, zoneID: zone.zoneID)
            }
            record = self.updateRecord(record!, with: changedValues)
            
            privateDB.save(record!, completionHandler: { savedRecord, error in
                
                if let record = savedRecord {
                    print(">>>>> 2. Record saved to CloudKit: \(record)")
                    let obj = self.delegate.save(record: record, in: obj)
                    completion(obj)
                } else {
                    completion(obj)
                }
            })
        }
    }
    
    func delete (_ obj: NSManagedObject, completion: @escaping ((_ success: Bool) -> Void)) {
        
        guard let _ = self.customZone, let privateDB = self.privateDB else {
            print("Not logged in or zone not created")
            completion(false)
            return
        }
        guard let recordId = obj.value(forKey: "recordId") as? CKRecordID else {
            completion(true)// The object is not yet uploaded to CK, means we can consider it was deleted with success
            return
        }
        privateDB.delete(withRecordID: recordId, completionHandler: { (recordName, error) in
            completion(error != nil)
        })
    }
}

extension RCCloudKit {
    
    func fetchCKRecord (of obj: NSManagedObject, completion: @escaping ((_ record: CKRecord?) -> Void)) {
        
        guard let privateDB = self.privateDB else {
            print("Not logged in or zone not created")
            completion(nil)
            return
        }
        guard let recordId = obj.value(forKey: "recordId") as? CKRecordID else {
            completion(nil)
            return
        }
        
        privateDB.fetch(withRecordID: recordId) { (record, error) in
            
            print(error)
            
            if let record = record {
                completion(record)
            } else {
                completion(nil)
            }
        }
    }
    
    fileprivate func objs (from records: [CKRecord]) -> [NSManagedObject] {
        return records.map { self.obj(from: $0) }
    }
    
    fileprivate func obj (from record: CKRecord) -> NSManagedObject {
        
        let entityName = record.recordType
        var obj: NSManagedObject? = dataSource.managedObject(from: record)
        if obj == nil {
            print("NSManagedObject for recordName \(record.recordID.recordName) not found, creating one now")
            obj = NSEntityDescription.insertNewObject(forEntityName: entityName, into: moc)
        }
        obj = updateObj(obj!, with: record)
        print(obj)
        
        return obj!
    }
    
    fileprivate func updateObj (_ obj: NSManagedObject, with record: CKRecord) -> NSManagedObject {
        
        for key in record.allKeys() {
            obj.setValue(record[key], forKey: key)
        }
        return delegate.save(record: record, in: obj)
    }
    
    fileprivate func updateRecord (_ record: CKRecord, with changedValues: [String: Any]) -> CKRecord {
        
        for (key, value) in changedValues {
            record[key] = value as? CKRecordValue
        }
        
        return record
    }
}
