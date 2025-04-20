//
// © 2024-present https://github.com/cengiz-pz
//

#import <Foundation/Foundation.h>

#import "notification_scheduler_plugin.h"
#import "notification_scheduler_plugin_implementation.h"

#import "core/config/engine.h"


NotificationSchedulerPlugin *plugin;

void notification_scheduler_plugin_init() {
	plugin = memnew(NotificationSchedulerPlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("NotificationSchedulerPlugin", plugin));
}

void notification_scheduler_plugin_deinit() {
	if (plugin) {
	   memdelete(plugin);
   }
}
