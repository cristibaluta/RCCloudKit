# RCCloudKit
A simple lib to sync CoreData to CloudKit

## Usage in objc

    cloudkit = [[RCCloudKit alloc] initWithMoc:context identifier:@"iCloud.com...." zoneName:@"SomeZoneName"];
    cloudkit.dataSource = self;
    sync = [[RCCloudKitSyncer alloc] initWithMoc:context ck:cloudkit];

    cloudkit.didCreateZone = ^{
        [sync start:^(BOOL containsChanges) {

        }];
    };

## Requirements

The CoreData entities must contain this fields: date: Date, recordId: CKRecord, recordName: String, markedForDeletion: Bool = false by default

## How it works

CoreData objects are saved to CloudKit automatically after you save the main context. Aditionally you can start the sync manually after you are sure the zone was created. 
