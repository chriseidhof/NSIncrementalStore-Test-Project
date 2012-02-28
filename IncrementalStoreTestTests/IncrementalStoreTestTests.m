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
#import "NSURLConnectionVCR.h"

@interface IncrementalStoreTestTests () {
 NSManagedObjectContext* moc;   
}

@end

@implementation IncrementalStoreTestTests

- (void)setUp
{
    [super setUp];
    
    NSError* error = nil;
    STAssertTrue([NSURLConnectionVCR startVCRWithPath:@"IncrementalStoreTestTests/Fixtures/VCRTapes" error:&error], @"VCR failed to start: %@", error);
    
    NSURL *modelURL;
    if ([[[NSBundle mainBundle] executablePath] rangeOfString:@"otest"].length != 0) {
        // Test bundle is run headless, find model inside the octest bundle:
        modelURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"BandCamp" withExtension:@"momd"];
    } else {
        // The test bundle is injected into iPhone app, find model there:
        modelURL = [[NSBundle mainBundle] URLForResource:@"BandCamp" withExtension:@"momd"];
    }
    NSManagedObjectModel* model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];    


    [NSPersistentStoreCoordinator registerStoreClass:[BandCampIS class] forStoreType:BANDCAMP_STORE_TYPE];
    NSPersistentStoreCoordinator* coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSError* err = nil;
    [coordinator addPersistentStoreWithType:BANDCAMP_STORE_TYPE configuration:nil URL:nil options:nil error:&err];
    moc = [[NSManagedObjectContext alloc] init];
    [moc setPersistentStoreCoordinator:coordinator];
}

- (void)tearDown
{
    NSError* error = nil;
    STAssertTrue([NSURLConnectionVCR stopVCRWithError:&error], @"VCR failed to stop: %@", error);

    [super tearDown];
}

#pragma mark Convenience methods

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

#pragma mark Tests

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
       NSLog(@"title: %@", album.title);
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
