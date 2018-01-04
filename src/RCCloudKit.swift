//
//  Created by Cristian Baluta on 09/06/16.
//  Copyright © 2016 Cristian Baluta. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

@objc protocol RCCloudKitDataSource {
    // Provide the NSManagedObject corresponding to the CKRecord. If none provided, it will be created.
    func managedObject(from record: CKRecord) -> NSManagedObject?
    func recordID(from managedObject: NSManagedObject) -> CKRecordID?
    // This are the NSManagedObjects that were never uploaded or the modifiedDate is newer than the lastUploadDate provided by RCCloudKit
    func managedObjectsToUpload() -> [NSManagedObject]
    // There are 2 ways to handle deleted objects:
    // 1. you move them to a new table with deleted objects
    // 2. you mark them as deleted and make sure you don't use them in the app anymore
    // After they are deleted from CloudKit they'll be deleted permanently from CoreData too.
    func managedObjectsToDelete() -> [NSManagedObject]
}

@objc protocol RCCloudKitDelegate {
    // This is your responsability to delete from CoreData the coresponding NSManagedObject
    func delete(with recordID: CKRecordID)
    // This is your responsability to save the CKRecord reference to the NSManagedObject
    func save(record: CKRecord, in managedObject: NSManagedObject) -> NSManagedObject
}

@objc class RCCloudKit: NSObject {
    
    internal var container: CKContainer?
    internal var privateDB: CKDatabase?
    internal var customZone: CKRecordZone?
    var moc: NSManagedObjectContext!
    var dataSource: RCCloudKitDataSource!
    var delegate: RCCloudKitDelegate!
    var didCreateZone: (() -> Void)?
    
    convenience init(moc: NSManagedObjectContext, identifier: String, zoneName: String) {
        self.init()
        self.moc = moc
        dataSource = RCCloudKitDefaultDataSource(moc: moc)
        delegate = RCCloudKitDefaultDelegate(moc: moc)
        container = CKContainer(identifier: identifier)
        privateDB = container?.privateCloudDatabase
        privateDB!.save( CKRecordZone(zoneName: zoneName) ) { (recordZone, err) in
            print("Zone created \(String(describing: recordZone))")
            if err == nil {
                self.customZone = recordZone
                self.didCreateZone?()
            }
        }
    }
    
    func fetchChangedRecords (token: CKServerChangeToken?,
                              completion: @escaping ((_ changedRecords: [CKRecord], _ deletedRecordsIds: [CKRecordID]) -> Void)) {
        
        var changedRecords = [CKRecord]()
        var deletedRecordsIds = [CKRecordID]()

        guard let customZone = self.customZone, let privateDB = self.privateDB else {
            print("Not logged in or zone not created")
            completion(changedRecords, deletedRecordsIds)
            return
        }
        
        let options = CKFetchRecordZoneChangesOptions()
        options.previousServerChangeToken = token
        let op = CKFetchRecordZoneChangesOperation(recordZoneIDs: [customZone.zoneID], 
                                                   optionsByRecordZoneID: [customZone.zoneID: options])
        op.fetchAllChanges = true
        op.recordChangedBlock = { record in
//            print(record)
            changedRecords.append(record)
        }
        op.recordWithIDWasDeletedBlock = { (recordName, id) in
//            print(recordName)
            deletedRecordsIds.append(recordName)
        }
        op.recordZoneFetchCompletionBlock = { (zoneId, serverChangeToken, clientChangeTokenData, more, error) in
//            print(serverChangeToken)
//            print(clientChangeTokenData)
            if !more {
                completion(changedRecords, deletedRecordsIds)
                UserDefaults.standard.serverChangeToken = serverChangeToken
            }
        }
//        op.recordZoneChangeTokensUpdatedBlock = { (zoneId, serverChangeToken, clientChangeTokenData) in
//            print(serverChangeToken)
//            print(clientChangeTokenData)
//            UserDefaults.standard.serverChangeToken = serverChangeToken
//        }
//        op.fetchRecordZoneChangesCompletionBlock = { error in
//            print(error)
//            completion(changedRecords, deletedRecordsIds)
//        }
        
        privateDB.add(op)
    }
    
    func fetchRecords (ofType type: String, predicate: NSPredicate, completion: @escaping ((_ ckRecord: [CKRecord]?) -> Void)) {
        
        guard let customZone = self.customZone, let privateDB = self.privateDB else {
            print("Not logged in or zone not created")
            return
        }
        
        let query = CKQuery(recordType: type, predicate: predicate)
        privateDB.perform(query, inZoneWith: customZone.zoneID) { (results: [CKRecord]?, error) in
            
            if let results = results {
                completion(results)
            } else {
                completion(nil)
            }
        }
    }
}

