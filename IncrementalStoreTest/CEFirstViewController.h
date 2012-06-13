//
//  CEFirstViewController.h
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/13/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CEFirstViewController : UITableViewController <NSFetchedResultsControllerDelegate>
@property (nonatomic, readwrite, strong) NSManagedObjectContext *moc;

- (void)setNeedsUpdateFetchedResultsController;

@end
