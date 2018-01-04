# RCCloudKit
A simple lib to sync CoreData to CloudKit

## Usage

    cloudkit = RCCloudKit(moc:context, identifier:@"iCloud.com....", zoneName:@"SomeZoneName")
    sync = RCCloudKitSynchronizer(moc:context, ck:cloudkit)

    cloudkit.didCreateZone = {
        sync.start { containsChanges in

        }
    }

## Requirements

The CoreData entities must contain this fields:
  1. date: Date
  2. recordId: CKRecord
  3. recordName: String (Noticed bugs where the fetch from CoreData was not working with the recordId)
  4. markedForDeletion: Bool = false by default
  
  If this does not satisfy you, you can create your own dataSource and delegate and use different logic.

## How it works

CoreData objects are saved to CloudKit automatically after you save the main context. Aditionally you can start the sync manually after you are sure the zone was created. 
