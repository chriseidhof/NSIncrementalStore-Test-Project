//
//  CEAppDelegate.m
//  IncrementalStoreTest
//
//  Created by Chris Eidhof on 2/13/12.
//  Copyright (c) 2012 Chris Eidhof. All rights reserved.
//

#import "CEAppDelegate.h"
#import "CEFirstViewController.h"
#import "CESecondViewController.h"
#import "BandCampIS.h"

@implementation CEAppDelegate {
    NSPersistentStoreCoordinator* persistentstoreCoordinator;
}

@synthesize window = _window;
@synthesize tabBarController = _tabBarController;

- (NSPersistentStoreCoordinator*)persistentstoreCoordinator {
    if (persistentstoreCoordinator) {
        return persistentstoreCoordinator;
    }
    persistentstoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[BandCampIS model]];
    NSError* err = nil;
    BandCampIS *store = (BandCampIS*)[persistentstoreCoordinator addPersistentStoreWithType:[BandCampIS type] configuration:nil URL:nil options:nil error:&err];
    if (store == nil) {
        NSLog(@"Something went wrong adding a BandCampIS store: %@", err);
    }
    return persistentstoreCoordinator;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        
    // Override point for customization after application launch.
    CEFirstViewController *viewController1 = [[CEFirstViewController alloc] initWithNibName:@"CEFirstViewController" bundle:nil];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController1];
    CESecondViewController *viewController2 = [[CESecondViewController alloc] initWithNibName:@"CESecondViewController" bundle:nil];
    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.viewControllers = [NSArray arrayWithObjects:navigationController, viewController2, nil];
    
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [moc setPersistentStoreCoordinator:[self persistentstoreCoordinator]];
    viewController1.moc = moc;
    
    self.window.rootViewController = self.tabBarController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

/*
// Optional UITabBarControllerDelegate method.
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController
{
}
*/

/*
// Optional UITabBarControllerDelegate method.
- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed
{
}
*/

@end
