//
// © 2024-present https://github.com/cengiz-pz
//

#import <UserNotifications/UserNotifications.h>

#import "notification_scheduler_plugin_implementation.h"
#import "nsp_converter.h"
#import "nsp_delegate.h"

struct NSPDelegateInitializer {
	NSPDelegateInitializer() {
		UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
		center.delegate = [NSPDelegate shared];
		[center getNotificationSettingsWithCompletionHandler: ^(UNNotificationSettings * settings) {
			NSLog(@"NSPDelegateInitializer- authorization status: %ld", (long) settings.authorizationStatus);
			[NSPDelegate shared].authorizationStatus = settings.authorizationStatus;
		}];
	}
};
static NSPDelegateInitializer initializer;

@implementation NSPDelegate

- (instancetype) init {
	self = [super init];

	self.dismissedNotificationsAtStartup = [[NSMutableArray alloc] init];
	self.openedNotificationsAtStartup = [[NSMutableArray alloc] init];

	return self;
}

+ (instancetype) shared {
	static NSPDelegate* sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[NSPDelegate alloc] init];
	});
	return sharedInstance;
}

- (void) userNotificationCenter:(UNUserNotificationCenter*) center
			didReceiveNotificationResponse:(UNNotificationResponse*) response
			withCompletionHandler:(void (^)()) completionHandler {
	NSLog(@"DEBUG: userNotificationCenter didReceiveNotificationResponse action id: %@.", response.actionIdentifier);
	if ([response.actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
		NSLog(@"DEBUG: userNotificationCenter didReceiveNotificationResponse user dismissed notification id: %@.", response.notification.request.identifier);
		NotificationSchedulerPlugin* plugin = NotificationSchedulerPlugin::get_singleton();
		if (plugin) {
			plugin->emit_signal(NOTIFICATION_DISMISSED_SIGNAL, [response.notification.request.identifier intValue]);
			plugin->handle_completion(response.notification.request.identifier);
		} else {
			NSLog(@"INFO: Plugin is not ready to process notification %@.", response.notification.request.identifier);
			[self.dismissedNotificationsAtStartup addObject: response.notification.request.identifier];
		}
	}
	else if ([response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
		NSLog(@"DEBUG: userNotificationCenter didReceiveNotificationResponse user launched app for notification id: %@.", response.notification.request.identifier);
		NotificationSchedulerPlugin* plugin = NotificationSchedulerPlugin::get_singleton();
		if (plugin) {
			plugin->emit_signal(NOTIFICATION_OPENED_SIGNAL, [response.notification.request.identifier intValue]);
			plugin->handle_completion(response.notification.request.identifier);
		} else {
			NSLog(@"INFO: Plugin is not ready to process notification %@.", response.notification.request.identifier);
			[self.openedNotificationsAtStartup addObject: response.notification.request.identifier];
		}
	}
	else {
		NSLog(@"ERROR: Unexpected action identifier: %@", response.actionIdentifier);
	}
}

- (void) userNotificationCenter:(UNUserNotificationCenter*) center
			willPresentNotification:(UNNotification*) notification
			withCompletionHandler:(void (^)(UNNotificationPresentationOptions options)) completionHandler {
	NSLog(@"DEBUG: userNotificationCenter willPresentNotification id: %@.", notification.request.identifier);
	completionHandler(UNNotificationPresentationOptionSound);
	NotificationSchedulerPlugin* plugin = NotificationSchedulerPlugin::get_singleton();
	if (plugin) {
		plugin->emit_signal(NOTIFICATION_OPENED_SIGNAL, [notification.request.identifier intValue]);
		plugin->handle_completion(notification.request.identifier);
	} else {
		NSLog(@"INFO: Plugin is not ready to process notification %@.", notification.request.identifier);
		[self.openedNotificationsAtStartup addObject: notification.request.identifier];
	}
}

- (void) userNotificationCenter:(UNUserNotificationCenter*) center openSettingsForNotification:(UNNotification*) notification {
	NSLog(@"DEBUG: userNotificationCenter openSettingsForNotification.");
}

@end
