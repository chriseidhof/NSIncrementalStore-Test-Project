//
//  CEFirstViewController.m
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/13/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import "CEFirstViewController.h"
#import "Band.h"
#import "NSArray+Map.h"
#import "NSIncrementalStore+Async.h"

@implementation CEFirstViewController {
    NSFetchedResultsController *fetchedResultsController;
    __weak IBOutlet UISearchBar *searchBar;
}
@synthesize moc;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"Find bands", @"Find bands");
        self.navigationItem.prompt = @"Enter search query.";
        self.tabBarItem.image = [UIImage imageNamed:@"first"];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(testInsertBand)];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(testReset)];
    }
    return self;
}

#pragma mark - Testing out stuff

- (void)updateCount {
    self.navigationItem.title = [NSString stringWithFormat:@"%i objects in moc", [[[self moc] registeredObjects] count]];
}

- (void)testInsertBand {
    Band* band = [NSEntityDescription insertNewObjectForEntityForName:@"Band" inManagedObjectContext:self.moc];
    band.name = searchBar.text.length ? searchBar.text : @"house";
    [self updateCount];
}

- (void)testReset {
    [self.moc reset];
    [self updateCount];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidUnload {
    searchBar = nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setNeedsUpdateFetchedResultsController) object:nil];
    [super viewDidUnload];
}

#pragma mark - SearchBarDelegate stuff

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setNeedsUpdateFetchedResultsController) object:nil];
    if (searchText.length < 2) {
        // If searchText too short, clear immediately:
        [self setNeedsUpdateFetchedResultsController];
    } else {
        // Otherwise, wait a bit:
        [self performSelector:@selector(setNeedsUpdateFetchedResultsController) withObject:nil afterDelay:0.3];
    }
}

#pragma mark - UITableView delegate stuff

- (void)configureCell:(UITableViewCell*)cell withObject:(NSManagedObject*)object {
    if ([object isKindOfClass:[Band class]]) {
        cell.textLabel.text = [(Band*)object name];
    }
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"CellStyleSubtitle";
    
    UITableViewCell* cell = [aTableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];   
    }
    
    // Configure the cell.
    id selectedObject = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    [self configureCell:cell withObject:selectedObject];
    
    return cell;
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSManagedObject* object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    
    // Do something with object...
    NSLog(@"didSelect: %@", object);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)_tableView {
    return [[[self fetchedResultsController] sections] count];
}

- (NSInteger)tableView:(UITableView *)_tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [[[self fetchedResultsController] sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}


#pragma mark - NSFetchedResultsControllerDelegate stuff

- (NSFetchRequest*)fetchRequest {
    NSString* searchQuery = [searchBar text];
    if (searchQuery.length < 2) {
        return nil;
    }
    
    NSAsyncFetchRequest *fetchRequest = [[NSAsyncFetchRequest alloc] init];
    fetchRequest.entity = [NSEntityDescription entityForName:@"Band" inManagedObjectContext:self.moc];
    fetchRequest.predicate = [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForKeyPath:@"name"] rightExpression:[NSExpression expressionForConstantValue:searchQuery] modifier:NSDirectPredicateModifier type:NSEqualToPredicateOperatorType options:NSDiacriticInsensitivePredicateOption | NSCaseInsensitivePredicateOption];
    fetchRequest.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    fetchRequest.returnsCachedResultsImmediately = YES;
    
    fetchRequest.willStartBlock = ^{
        self.navigationItem.prompt = @"Starting to load...";
    };
    
    fetchRequest.didFinishBlock = ^(id results, NSError *error){
        // Done:
        [self updateCount];
        if (results) {
            self.navigationItem.prompt = @"Done loading.";
        } else {
            self.navigationItem.prompt = [NSString stringWithFormat:@"Error: %@", error];
        }
    };
    
    return fetchRequest;
}

- (NSFetchedResultsController*)fetchedResultsController {
    if (fetchedResultsController == nil) {
        NSFetchRequest* fetchRequest = [self fetchRequest];
        if (fetchRequest == nil) {
            fetchedResultsController = nil;
        } else {
            fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:[self moc] sectionNameKeyPath:nil cacheName:nil];
            [fetchedResultsController setDelegate:self];
        }
    }
    
    // If the tableView isn't already loaded, performFetch straight away:
    // Otherwise, don't & be lazy. It will be triggered when the tableView triggers it's delegate methods.
    if (fetchedResultsController && self.tableView && fetchedResultsController.fetchedObjects == nil) {
        
        NSError* error = nil;
        if ([fetchedResultsController performFetch:&error] == NO) {
            NSLog(@"Error performFetch: %@", error);
        }
        
        if (fetchedResultsController.fetchedObjects.count > 0) {
            self.navigationItem.prompt = @"Showing cached results..";
        } else {
            self.navigationItem.prompt = @"No cache for this query.";
        }
    }
    
    return fetchedResultsController;
}

- (void)setNeedsUpdateFetchedResultsController {
    // Cleanup old fetchedResultsController:
    [fetchedResultsController setDelegate:nil];
    fetchedResultsController = nil;
    
    // Reload the tableView's data:
    if (self.tableView) {
        // This will trigger the delegate methods again, which will in turn trigger the creation of a new fetchedResultsController
        [self.tableView reloadData];
    }
    
    [self updateCount];
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
	[self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController*)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath*)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath*)newIndexPath {    
	switch(type) {
		case NSFetchedResultsChangeInsert:
			[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationMiddle];
			break;
		case NSFetchedResultsChangeDelete:
			[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
			break;
		case NSFetchedResultsChangeUpdate:
		{
			UITableViewCell* theCell = [self.tableView cellForRowAtIndexPath:indexPath];
            [self configureCell:theCell withObject:anObject];
			break;
		}
		case NSFetchedResultsChangeMove: {
            BOOL newFirst = ([newIndexPath compare:indexPath] == NSOrderedDescending);
			[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]	withRowAnimation:newFirst? UITableViewRowAnimationBottom : UITableViewRowAnimationTop];
			[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:newFirst? UITableViewRowAnimationTop : UITableViewRowAnimationBottom];
			break;
        }
	}
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
	switch(type) {
		case NSFetchedResultsChangeInsert:
			[self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationBottom];
			break;
		case NSFetchedResultsChangeDelete:
			[self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationBottom];
			break;
	}
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

@end
