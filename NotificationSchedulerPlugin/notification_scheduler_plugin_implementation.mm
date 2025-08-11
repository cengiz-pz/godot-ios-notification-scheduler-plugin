//
// © 2024-present https://github.com/cengiz-pz
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <UIKit/UIKit.h>

#include "core/config/project_settings.h"

#import "notification_scheduler_plugin_implementation.h"
#import "nsp_converter.h"
#import "channel_data.h"


String const INITIALIZATION_COMPLETED_SIGNAL = "initialization_completed";
String const NOTIFICATION_OPENED_SIGNAL = "notification_opened";
String const NOTIFICATION_DISMISSED_SIGNAL = "notification_dismissed";
String const PERMISSION_GRANTED_SIGNAL = "permission_granted";
String const PERMISSION_DENIED_SIGNAL = "permission_denied";

NotificationSchedulerPlugin* NotificationSchedulerPlugin::instance = NULL;


void NotificationSchedulerPlugin::_bind_methods() {
	ClassDB::bind_method(D_METHOD("initialize"), &NotificationSchedulerPlugin::initialize);
	ClassDB::bind_method(D_METHOD("has_post_notifications_permission"), &NotificationSchedulerPlugin::has_post_notifications_permission);
	ClassDB::bind_method(D_METHOD("request_post_notifications_permission"), &NotificationSchedulerPlugin::request_post_notifications_permission);
	ClassDB::bind_method(D_METHOD("create_notification_channel"), &NotificationSchedulerPlugin::create_notification_channel);
	ClassDB::bind_method(D_METHOD("schedule"), &NotificationSchedulerPlugin::schedule);
	ClassDB::bind_method(D_METHOD("cancel"), &NotificationSchedulerPlugin::cancel);
	ClassDB::bind_method(D_METHOD("set_badge_count"), &NotificationSchedulerPlugin::set_badge_count);
	ClassDB::bind_method(D_METHOD("get_notification_id"), &NotificationSchedulerPlugin::get_notification_id);
	ClassDB::bind_method(D_METHOD("open_app_info_settings"), &NotificationSchedulerPlugin::open_app_info_settings);

	ADD_SIGNAL(MethodInfo(INITIALIZATION_COMPLETED_SIGNAL));
	ADD_SIGNAL(MethodInfo(NOTIFICATION_OPENED_SIGNAL, PropertyInfo(Variant::INT, "notification_id")));
	ADD_SIGNAL(MethodInfo(NOTIFICATION_DISMISSED_SIGNAL, PropertyInfo(Variant::INT, "notification_id")));
	ADD_SIGNAL(MethodInfo(PERMISSION_GRANTED_SIGNAL, PropertyInfo(Variant::STRING, "permission_name")));
	ADD_SIGNAL(MethodInfo(PERMISSION_DENIED_SIGNAL, PropertyInfo(Variant::STRING, "permission_name")));
}

void NotificationSchedulerPlugin::initialize() {
	NSLog(@"NotificationSchedulerPlugin initialize");

	delegate = [NSPDelegate shared];
	notifications = [NSMutableDictionary dictionaryWithCapacity:10];

	instance->emit_signal(INITIALIZATION_COMPLETED_SIGNAL);

	// Check if app was started due to an action on a notification.
	NSLog(@"NotificationSchedulerPlugin initialize found %lu dismissed notifications at startup.", [delegate.dismissedNotificationsAtStartup count]);
	if ([delegate.dismissedNotificationsAtStartup count] > (NSUInteger) 0) {
		for (int i = 0; i < [delegate.dismissedNotificationsAtStartup count]; i++) {
			NSString* identifier = [delegate.dismissedNotificationsAtStartup objectAtIndex: i];
			instance->emit_signal(NOTIFICATION_DISMISSED_SIGNAL, [identifier intValue]);
			// instance->handle_completion(request.identifier); // local cache was removed after app shutdown
		}
	}
	[delegate.dismissedNotificationsAtStartup removeAllObjects];

	NSLog(@"NotificationSchedulerPlugin initialize found %lu opened notifications at startup.", [delegate.openedNotificationsAtStartup count]);
	if ([delegate.openedNotificationsAtStartup count] > (NSUInteger) 0) {
		for (int i = 0; i < [delegate.openedNotificationsAtStartup count]; i++) {
			NSString* identifier = [delegate.openedNotificationsAtStartup objectAtIndex: i];
			NSLog(@"NotificationSchedulerPlugin found notification identifier %@.", identifier); 
			instance->emit_signal(NOTIFICATION_OPENED_SIGNAL, [identifier intValue]);
			// instance->handle_completion(request.identifier); // local cache was removed after app shutdown
		}
	}
	[delegate.openedNotificationsAtStartup removeAllObjects];
}

bool NotificationSchedulerPlugin::has_post_notifications_permission() {
	NSLog(@"NotificationSchedulerPlugin has_post_notifications_permission");

	bool has_authorization = false;

	switch(delegate.authorizationStatus) {
		case UNAuthorizationStatusAuthorized:
		case UNAuthorizationStatusProvisional:
		case UNAuthorizationStatusEphemeral:
			has_authorization = true;
			break;
		case UNAuthorizationStatusDenied:
		case UNAuthorizationStatusNotDetermined:
			has_authorization = false;
			break;
		default:
			has_authorization = false;
	}

	return has_authorization;
}

Error NotificationSchedulerPlugin::request_post_notifications_permission() {
	NSLog(@"NotificationSchedulerPlugin request_post_notifications_permission");

	UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];

	[center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge)
				completionHandler: ^(BOOL granted, NSError * _Nullable error) {
		if (error) {
			NSLog(@"ERROR: Unable to request notification authorization: %@", error.localizedDescription);
		}
		else {
			if (granted) {
				delegate.authorizationStatus = UNAuthorizationStatusAuthorized;
				this->call_deferred("emit_signal", PERMISSION_GRANTED_SIGNAL, "");
			}
			else {
				delegate.authorizationStatus = UNAuthorizationStatusDenied;
				this->call_deferred("emit_signal", PERMISSION_DENIED_SIGNAL, "");
			}
		}
	}];

	return OK;
}

Error NotificationSchedulerPlugin::create_notification_channel(Dictionary dict) {
	NSLog(@"NotificationSchedulerPlugin create_notification_channel");

	ChannelData* channelData = [[ChannelData alloc] initWithDictionary:dict];
	if (@available(iOS 11.0, *)) {
		UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
		UNNotificationCategory* newCategory = [UNNotificationCategory categoryWithIdentifier: channelData.channelId
					actions: [NSArray array] intentIdentifiers: [NSArray array] options: UNNotificationCategoryOptionHiddenPreviewsShowTitle];

		[center setNotificationCategories: [NSSet setWithObjects:(UNNotificationCategory*) newCategory, nil]];
	}
	else {
		NSLog(@"ERROR: NotificationSchedulerPlugin failed to create channel. iOS 11 is required.");
	}

	return OK;
}

Error NotificationSchedulerPlugin::schedule(Dictionary dict) {
	NSLog(@"NotificationSchedulerPlugin schedule");

	NotificationData* notificationData = [[NotificationData alloc] initWithDictionary:dict];
	NSPNotification* notification = [[NSPNotification alloc] initWithId:notificationData.notificationId];

	[notification schedule:notificationData];

	notifications[notification.notificationId] = notification;

	return OK;
}

Error NotificationSchedulerPlugin::cancel(int notificationId) {
	NSLog(@"NotificationSchedulerPlugin cancel notification with id '%d'", notificationId);

	NSString* key = [NSString stringWithFormat:@"%d",notificationId];
	NSPNotification* notification = [notifications objectForKey: key];
	if (notification == nil) {
		NSLog(@"NotificationSchedulerPlugin::cancel: ERROR: Notification with ID '%d' not found!", notificationId);
		return FAILED;
	}
	else {
		UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
		[center removePendingNotificationRequestsWithIdentifiers: @[ notification.notificationId ]];
		[center removeDeliveredNotificationsWithIdentifiers: @[ notification.notificationId ]];
		[notifications removeObjectForKey: key];
	}

	return OK;
}

void NotificationSchedulerPlugin::set_badge_count(int badgeCount) {
	NSLog(@"NotificationSchedulerPlugin set_badge_count with '%d'", badgeCount);

	UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
	[center setBadgeCount: (NSInteger) badgeCount withCompletionHandler:^(NSError* _Nullable error) {
		if (error != nil) {
			NSLog(@"ERROR: Unable to set badge count: %@", error.localizedDescription);
		} else {
			NSLog(@"DEBUG: badge count has been successfully set to %d.", badgeCount);
		}
	}];
}

int NotificationSchedulerPlugin::get_notification_id(int defaultValue) {
	if (lastReceivedNotificationId) {
		return lastReceivedNotificationId;
	}
	else {
		return defaultValue;
	}
}

void NotificationSchedulerPlugin::open_app_info_settings() {
	if (@available(iOS 15.4, *)) {
		// Create the URL that deep links to your app's custom settings.
		NSURL *url = [[NSURL alloc] initWithString:UIApplicationOpenNotificationSettingsURLString];
		// Ask the system to open that URL.
		[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
	}
	else {
		NSLog(@"NotificationSchedulerPlugin::open_app_info_settings: ERROR: iOS version 15.4 or greater is required!");
	}
}

void NotificationSchedulerPlugin::handle_completion(NSString* notificationId) {
	NSLog(@"NotificationSchedulerPlugin handle_completion for %@", notificationId);
	NSPNotification* notification = [notifications objectForKey: notificationId];
	if (notification == nil) {
		NSLog(@"NotificationSchedulerPlugin::handle_completion: WARNING: Notification with ID '%@' not found in cache!", notificationId);
	}
	else {
		if (notification.repeatInterval > 0) {
			[notification scheduleRepeating];
		}
	}
	lastReceivedNotificationId = [notificationId intValue];
}

NotificationSchedulerPlugin* NotificationSchedulerPlugin::get_singleton() {
	return instance;
}

NotificationSchedulerPlugin::NotificationSchedulerPlugin() {
	NSLog(@"NotificationSchedulerPlugin constructor");

	ERR_FAIL_COND(instance != NULL);
	
	instance = this;
}

NotificationSchedulerPlugin::~NotificationSchedulerPlugin() {
	NSLog(@"NotificationSchedulerPlugin destructor");
	if (instance == this) {
		instance = NULL;
	}
}
