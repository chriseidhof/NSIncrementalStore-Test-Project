//
//  IncrementalStoreTestTests.m
//  IncrementalStoreTestTests
//
//  Created by Chris Eidhof on 2/13/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import "IncrementalStoreTestTests.h"
#import "BandCampIS.h"
#import "Band.h"
#import "Album.h"
#import "Track.h"

@interface IncrementalStoreTestTests () {
 NSManagedObjectContext* moc;   
}

@end

@implementation IncrementalStoreTestTests

- (void)setUp
{
    [super setUp];
    
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"BandCamp" withExtension:@"momd"];
    NSManagedObjectModel* model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];    

    
    [NSPersistentStoreCoordinator registerStoreClass:[BandCampIS class] forStoreType:MY_STORE_TYPE];
    NSPersistentStoreCoordinator* coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSError* err = nil;
    NSURL* url = [NSURL URLWithString:@"http://api.bandcamp.com/api/"];
    [coordinator addPersistentStoreWithType:MY_STORE_TYPE configuration:nil URL:url options:nil error:&err];
    moc = [[NSManagedObjectContext alloc] init];
    [moc setPersistentStoreCoordinator:coordinator];

    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (Band*)rueRoyale {
    NSEntityDescription *entityDescription = [NSEntityDescription
                                              entityForName:@"Band" inManagedObjectContext:moc];
    
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"name == %@", @"Rue Royale"];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = entityDescription;
    fetchRequest.predicate = predicate;
    
    NSArray *results = [moc executeFetchRequest:fetchRequest error:nil];
    Band* band = [results lastObject];
    return band;
}

- (Album*)illinois
{
    NSEntityDescription *entityDescription = [NSEntityDescription
                                              entityForName:@"Album" inManagedObjectContext:moc];
    
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"album_id == %d", 781775666];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = entityDescription;
    fetchRequest.predicate = predicate;
    
    NSArray *results = [moc executeFetchRequest:fetchRequest error:nil];
    return [results lastObject];
    
}

- (void)testFetchBandByName
{
    Band* band = [self rueRoyale];
    STAssertEqualObjects(band.name, @"Rue Royale", @"Name should be Rue Royale");
}

- (void)testFetchBandDiscography
{
   Band* band = [self rueRoyale];
   BOOL foundGuideToAnEscape = NO;
   for(Album* album in band.discography) {
       foundGuideToAnEscape = foundGuideToAnEscape || [album.title isEqualToString:@"Guide to an Escape"];
   }
    STAssertTrue(foundGuideToAnEscape, @"One of the albums should be named 'Guide to an Escape'");
}

- (void)testFetchAlbumByAlbumId {
    Album* illinois = [self illinois];
    STAssertEqualObjects(illinois.title, @"Illinois", @"Title should be Illinois");
}

- (void)testFetchTracks {
    Album* illinois = [self illinois];
    STAssertTrue(illinois.tracks.count == 22, @"Should be 22 tracks");
    BOOL foundChicago = NO;
    for(Track* track in illinois.tracks) {
        foundChicago = foundChicago || [track.title isEqualToString:@"Chicago"];
    }
    STAssertTrue(foundChicago, @"The track Chicago should be on the album");
}

@end
