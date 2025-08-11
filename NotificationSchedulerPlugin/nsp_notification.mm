//
// © 2024-present https://github.com/cengiz-pz
//

#import "nsp_notification.h"


@implementation NSPNotification

- (instancetype) initWithId:(int) notificationId {
	if ((self = [super init])) {
		self.notificationId = [NSString stringWithFormat:@"%d",notificationId];
		self.repeatInterval = 0;
	}
	return self;
}

- (void) schedule:(NotificationData*) notificationData {
	self.content = [[UNMutableNotificationContent alloc] init];
	self.content.title = notificationData.title;
	self.content.body = notificationData.content;
	self.content.categoryIdentifier = notificationData.channelId;
	self.content.sound = [UNNotificationSound defaultSound];

	UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:notificationData.delay
				repeats:NO];
	
	UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:self.notificationId content:self.content
				trigger:trigger];

	UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
	[center addNotificationRequest:request withCompletionHandler:^(NSError* _Nullable error) {
		if (error != nil) {
			NSLog(@"ERROR: Unable to add notification request: %@", error.localizedDescription);
		} else {
			NSLog(@"DEBUG: add notification request completed successfully.");
		}
	}];

	if (notificationData.badgeCount != nil) {
		[center setBadgeCount: [notificationData.badgeCount integerValue] withCompletionHandler:^(NSError* _Nullable error) {
			if (error != nil) {
				NSLog(@"ERROR: Unable to set badge count: %@", error.localizedDescription);
			} else {
				NSLog(@"DEBUG: badge count has been successfully set to %@.", notificationData.badgeCount);
			}
		}];
	}

	self.repeatInterval = notificationData.interval;
}

- (void) scheduleRepeating {
	if (self.repeatInterval > 0) {
		UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:self.repeatInterval
					repeats:YES];
		self.repeatInterval = 0;
	
		UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:self.notificationId content:self.content
					trigger:trigger];

		UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
		[center addNotificationRequest:request withCompletionHandler:^(NSError* _Nullable error) {
			if (error != nil) {
				NSLog(@"ERROR: Unable to add repeating notification request: %@", error.localizedDescription);
			} else {
				NSLog(@"DEBUG: add repeating notification request completed successfully.");
			}
		}];
	}
}

@end
