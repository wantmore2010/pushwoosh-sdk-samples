//
//  PushAirExtension.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2013
//

#import "PushAirExtension.h"
#import "PW_SBJsonParser.h"

#define DEFINE_ANE_FUNCTION(fn) FREObject (fn)(FREContext context, void* functionData, uint32_t argc, FREObject argv[])

NSString * FreToNSString(FREObject object)
{
	uint32_t string_length;
    const uint8_t *utf8_string;
    if (FREGetObjectAsUTF8(object, &string_length, &utf8_string) != FRE_OK)
    {
        return nil;
    }
	
    NSString* result = [NSString stringWithUTF8String:(char*)utf8_string];
	return result;
}

FREContext myCtx = 0;

char * g_tokenStr = 0;
char * g_registerErrStr = 0;
char * g_pushMessageStr = 0;
char * g_listenerName = 0;

DEFINE_ANE_FUNCTION(onPause)
{
	return nil;
}

DEFINE_ANE_FUNCTION(onResume)
{
	return nil;
}

DEFINE_ANE_FUNCTION(setBadgeNumber)
{
    int32_t value;
    if (FREGetObjectAsInt32(argv[0], &value) != FRE_OK)
    {
        return nil;
    }
    
    UIApplication *uiapplication = [UIApplication sharedApplication];
    uiapplication.applicationIconBadgeNumber = value;
	
    return nil;
}

extern int getPushNotificationMode();

DEFINE_ANE_FUNCTION(registerPush)
{
	if(g_tokenStr) {
		FREDispatchStatusEventAsync(myCtx, (uint8_t*)"TOKEN_SUCCESS", (uint8_t*)g_tokenStr);
		free(g_tokenStr); g_tokenStr = 0;
	}
	
	if(g_registerErrStr) {
		FREDispatchStatusEventAsync(myCtx, (uint8_t*)"TOKEN_FAIL", (uint8_t*)g_registerErrStr);
		free(g_registerErrStr); g_registerErrStr = 0;
	}
	
	if(g_pushMessageStr) {
		FREDispatchStatusEventAsync(myCtx, (uint8_t*)"PUSH_RECEIVED", (uint8_t*)g_pushMessageStr);
		free(g_pushMessageStr); g_pushMessageStr = 0;
	}
	
	[[UIApplication sharedApplication] registerForRemoteNotificationTypes:getPushNotificationMode()];
	
	return nil;
}

DEFINE_ANE_FUNCTION(unregisterPush)
{
	[[UIApplication sharedApplication] unregisterForRemoteNotifications];	
	return nil;
}

DEFINE_ANE_FUNCTION(setIntTag)
{
	NSString* tagName = FreToNSString(argv[0]);
    if (!tagName)
        return nil;
	
    int32_t tagValue;
	if (FREGetObjectAsInt32(argv[1], &tagValue) != FRE_OK)
	{
		return nil;
	}

	NSDictionary * dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:tagValue], tagName, nil];
	[[PushNotificationManager pushManager] setTags:dict];
	
	return nil;
}

DEFINE_ANE_FUNCTION(setStringTag)
{
	NSString* tagName = FreToNSString(argv[0]);
    if (!tagName)
        return nil;

	NSString* tagValue = FreToNSString(argv[1]);
    if (!tagValue)
        return nil;

	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:tagValue, tagName, nil];
	[[PushNotificationManager pushManager] setTags:dict];
	
	return nil;
}

//timeInSeconds, json string: {alertBody: text, alertAction:text, soundName:text, badge: int, custom: {json}}
DEFINE_ANE_FUNCTION(scheduleLocalNotification)
{
	int32_t interval;
	if (FREGetObjectAsInt32(argv[0], &interval) != FRE_OK)
	{
		return nil;
	}

	NSString* bodyJson = FreToNSString(argv[1]);
    if (!bodyJson)
        return nil;
	
	
	PW_SBJsonParser * json = [[PW_SBJsonParser alloc] init];
	NSDictionary *jsonDict =[json objectWithString:bodyJson];
	json = nil;
	
	if(!jsonDict)
		return nil;

	UILocalNotification* notification = [[UILocalNotification alloc] init];
	notification.fireDate = [NSDate dateWithTimeIntervalSinceNow: interval];
	notification.alertBody = [jsonDict objectForKey:@"alertBody"];
	notification.alertAction = [jsonDict objectForKey:@"alertAction"];
	
	if([jsonDict objectForKey:@"soundName"])
	{
		notification.soundName = [jsonDict objectForKey:@"soundName"];
	}
	else
	{
		notification.soundName = UILocalNotificationDefaultSoundName;
	}

	if([jsonDict objectForKey:@"badge"])
	{
		notification.applicationIconBadgeNumber = [[jsonDict objectForKey:@"badge"] intValue];
	}

	notification.userInfo = [jsonDict objectForKey:@"custom"];

    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
	
	return nil;
}

DEFINE_ANE_FUNCTION(clearAllLocalNotifications)
{
	[[UIApplication sharedApplication] cancelAllLocalNotifications];
	return nil;
}

DEFINE_ANE_FUNCTION(startGeoPushes)
{
	[[PushNotificationManager pushManager] startLocationTracking];
	
	return nil;
}

DEFINE_ANE_FUNCTION(stopGeoPushes)
{
	[[PushNotificationManager pushManager] stopLocationTracking];
	
	return nil;
}

void PushwooshContextInitializer(void* extData, const uint8_t* ctxType, FREContext ctx,
							   uint32_t* numFunctionsToTest, const FRENamedFunction** functionsToSet)
{
    // Register the links btwn AS3 and ObjC. (dont forget to modify the nbFuntionsToLink integer if you are adding/removing functions)
    NSInteger nbFuntionsToLink = 11;
    *numFunctionsToTest = nbFuntionsToLink;
    
    FRENamedFunction* func = (FRENamedFunction*) malloc(sizeof(FRENamedFunction) * nbFuntionsToLink);
    
    func[0].name = (const uint8_t*) "registerPush";
    func[0].functionData = NULL;
    func[0].function = &registerPush;

    func[1].name = (const uint8_t*) "setBadgeNumber";
    func[1].functionData = NULL;
    func[1].function = &setBadgeNumber;
    
    func[2].name = (const uint8_t*) "setIntTag";
    func[2].functionData = NULL;
    func[2].function = &setIntTag;
    
    func[3].name = (const uint8_t*) "setStringTag";
    func[3].functionData = NULL;
    func[3].function = &setStringTag;

    func[4].name = (const uint8_t*) "pause";
    func[4].functionData = NULL;
    func[4].function = &onPause;

    func[5].name = (const uint8_t*) "resume";
    func[5].functionData = NULL;
    func[5].function = &onResume;

	func[6].name = (const uint8_t*) "scheduleLocalNotification";
    func[6].functionData = NULL;
    func[6].function = &scheduleLocalNotification;

	func[7].name = (const uint8_t*) "clearLocalNotifications";
    func[7].functionData = NULL;
    func[7].function = &clearAllLocalNotifications;

    func[8].name = (const uint8_t*) "unregisterPush";
    func[8].functionData = NULL;
    func[8].function = &unregisterPush;

	func[9].name = (const uint8_t*) "startGeoPushes";
    func[9].functionData = NULL;
    func[9].function = &startGeoPushes;

	func[10].name = (const uint8_t*) "stopGeoPushes";
    func[10].functionData = NULL;
    func[10].function = &stopGeoPushes;

    *functionsToSet = func;
    
    myCtx = ctx;
}

void PushwooshContextFinalizer(FREContext ctx) {
    NSLog(@"ContextFinalizer()");
}

void PushwooshExtInitializer(void** extDataToSet, FREContextInitializer* ctxInitializerToSet, FREContextFinalizer* ctxFinalizerToSet )
{
    NSLog(@"Entering ExtInitializer()");
    
	*extDataToSet = NULL;
	*ctxInitializerToSet = &PushwooshContextInitializer;
	*ctxFinalizerToSet = &PushwooshContextFinalizer;
    
    NSLog(@"Exiting ExtInitializer()");
}

void PushwooshExtFinalizer(void *extData) {
	NSLog(@"ExtFinalizer()");
}

#import "PW_SBJsonWriter.h"

@implementation UIApplication(AdobeAirPushwoosh)

- (NSObject<PushNotificationDelegate> *)getPushwooshDelegate
{
	return (NSObject<PushNotificationDelegate> *)[UIApplication sharedApplication];
}

//succesfully registered for push notifications
- (void) onDidRegisterForRemoteNotificationsWithDeviceToken:(NSString *)token
{
	const char * str = [token UTF8String];
	if(!myCtx) {
		g_tokenStr = malloc(strlen(str)+1);
		strcpy(g_tokenStr, str);
		return;
	}

	FREDispatchStatusEventAsync(myCtx, (uint8_t*)"TOKEN_SUCCESS", (uint8_t*)str);
}

//failed to register for push notifications
- (void) onDidFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
	const char * str = [[error description] UTF8String];
	if(!myCtx) {
		g_registerErrStr = malloc(strlen(str)+1);
		strcpy(g_registerErrStr, str);
		return;
	}

	FREDispatchStatusEventAsync(myCtx, (uint8_t*)"TOKEN_FAIL", (uint8_t*)str);
}

//handle push notification, display alert, if this method is implemented onPushAccepted will not be called, internal message boxes will not be displayed
- (void) onPushAccepted:(PushNotificationManager *)pushManager withNotification:(NSDictionary *)pushNotification onStart:(BOOL)onStart
{
	NSMutableDictionary * pn = [pushNotification mutableCopy];
	[pn setObject:[NSNumber numberWithBool:onStart] forKey:@"onStart"];

	PW_SBJsonWriter * json = [[PW_SBJsonWriter alloc] init];
	NSString *jsonRequestData =[json stringWithObject:pn];
	json = nil;
	
	pn = nil;

	const char * str = [jsonRequestData UTF8String];
	
	if(!myCtx) {
		g_pushMessageStr = malloc(strlen(str)+1);
		strcpy(g_pushMessageStr, str);
		return;
	}

	FREDispatchStatusEventAsync(myCtx, (uint8_t*)"PUSH_RECEIVED", (uint8_t*)str);
}

@end
