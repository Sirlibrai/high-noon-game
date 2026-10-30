// HighNoonCloud: mirrors High Noon's save with iCloud key-value storage.
// Plain Objective-C with no Godot headers: it talks to the game through three
// small files in the app's Documents folder (see autoload/cloud_sync.gd):
//   cloud_status.json  written at launch so the game knows sync is running
//   cloud_out.json     the game's latest save; uploaded when it changes
//   cloud_in.json      iCloud's copy; written at launch, on return to the app,
//                      and whenever another device changes it
// Needs the iCloud key-value storage entitlement, which only paid Apple
// Developer Program teams can sign.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSString *const kSaveKey = @"highnoon.save";

@interface HNCloud : NSObject
@property(nonatomic, strong) NSString *lastPushed;
@property(nonatomic, strong) NSTimer *timer;
@end

@implementation HNCloud

+ (instancetype)shared {
	static HNCloud *instance;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ instance = [HNCloud new]; });
	return instance;
}

- (NSString *)path:(NSString *)name {
	NSString *docs = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
	return [docs stringByAppendingPathComponent:name];
}

- (void)start {
	NSUbiquitousKeyValueStore *kvs = [NSUbiquitousKeyValueStore defaultStore];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(externalChange:) name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification object:kvs];
	[nc addObserver:self selector:@selector(becameActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
	[nc addObserver:self selector:@selector(resigning:) name:UIApplicationWillResignActiveNotification object:nil];
	[kvs synchronize];
	BOOL signedIn = [[NSFileManager defaultManager] ubiquityIdentityToken] != nil;
	NSString *status = [NSString stringWithFormat:@"{\"running\": true, \"signed_in\": %@}", signedIn ? @"true" : @"false"];
	[status writeToFile:[self path:@"cloud_status.json"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
	[self pull];
	self.timer = [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:YES block:^(NSTimer *t) { [self push]; }];
}

- (void)pull {
	NSString *saved = [[NSUbiquitousKeyValueStore defaultStore] stringForKey:kSaveKey];
	if (saved.length > 0) {
		[saved writeToFile:[self path:@"cloud_in.json"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
	}
}

- (void)push {
	NSString *out = [NSString stringWithContentsOfFile:[self path:@"cloud_out.json"] encoding:NSUTF8StringEncoding error:nil];
	if (out.length == 0 || [out isEqualToString:self.lastPushed]) {
		return;
	}
	self.lastPushed = out;
	NSUbiquitousKeyValueStore *kvs = [NSUbiquitousKeyValueStore defaultStore];
	[kvs setString:out forKey:kSaveKey];
	[kvs synchronize];
}

- (void)externalChange:(NSNotification *)note {
	[self pull];
}

- (void)becameActive:(NSNotification *)note {
	[[NSUbiquitousKeyValueStore defaultStore] synchronize];
	[self pull];
}

- (void)resigning:(NSNotification *)note {
	[self push];
}

@end

// Called by Godot's iOS plugin loader (see HighNoonCloud.gdip). Godot declares these with C++
// linkage, so this file is Objective-C++ (.mm) and they are not extern "C".
void highnoon_cloud_init() {
	dispatch_async(dispatch_get_main_queue(), ^{ [[HNCloud shared] start]; });
}

void highnoon_cloud_deinit() {
	[[HNCloud shared] push];
}
