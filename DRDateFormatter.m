//
//  DRDateFormatter.m
//
//  This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported.
//  To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/
//

/*
 From: http://stackoverflow.com/questions/2993578/whats-wrong-with-how-im-using-nsdateformatter

 x           number
 xx          two digit number
 xxx         abbreviated name
 xxxx        full name

 a           AM/PM
 A           millisecond of day
 c           day of week (c,cc,ccc,cccc)
 d           day of month
 e           day of week (e,EEE,EEEE)
 F           week of month
 g           julian day (since 1/1/4713 BC)
 G           era designator (G=GGG,GGGG)
 h           hour (1-12, zero padded)
 H           hour (0-23, zero padded)
 L           month of year (L,LL,LLL,LLLL)
 m           minute of hour (0-59, zero padded)
 M           month of year (M,MM,MMM,MMMM)
 Q           quarter of year (Q,QQ,QQQ,QQQQ)
 s           seconds of minute (0-59, zero padded)
 S           fraction of second
 u           zero padded year
 v           general timezone (v=vvv,vvvv)
 w           week of year (0-53, zero padded)
 y           year (y,yy,yyyy)
 z           specific timezone (z=zzz,zzzz)
 Z           timezone offset +0000

 sql         y-M-d H:m:s
 rss         [E, ]d MMM y[y] H:m:s Z|z[zzz]
 */

////////////////////////////////////////////////////////////////////////////////

#import "DRDateFormatter.h"

static const NSTimeInterval kCSDateIntervalToBeConsideredRecent = 14400; // 4 hours
static const NSTimeInterval kCSSecondsInTwoHours = 7200;
static const NSTimeInterval kCSSecondsInOneHour = 3600;
static const NSTimeInterval kCSSecondsInTwoMinutes = 120;
static const NSTimeInterval kCSSecondsInOneMinute = 60;

////////////////////////////////////////////////////////////////////////////////

@interface DRDateFormatter ()

@property (nonatomic, strong, readwrite) NSDateFormatter* abbreviatedDateFormatter;
@property (nonatomic, strong, readwrite) NSDateFormatter *monthDayYearFormatter;
@property (nonatomic, strong, readwrite) NSDateFormatter* dateAndTimeFormatter;
@property (nonatomic, strong, readwrite) NSDateFormatter* dateAndWeekdayFormatter;
@property (nonatomic, strong, readwrite) NSDateFormatter *serverDateFormatter;
@end

@implementation DRDateFormatter

+ (id)sharedDateFormatter
{
    static DRDateFormatter *sharedDateFormatter = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedDateFormatter = [[DRDateFormatter alloc] init];
    });
    return sharedDateFormatter;
}

- (id)init
{
    if ( self = [super init] )
    {
        // Server dates are always UTC and use RFC 3339 format
        // See https://github.com/mwaterfall/MWFeedParser/blob/master/Classes/NSDate%2BInternetDateTime.m

        NSTimeZone *GMTTimezone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        NSLocale *en_US_POSIX = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        self.serverDateFormatter = [[NSDateFormatter alloc] init];
        [self.serverDateFormatter setLocale:en_US_POSIX];
        [self.serverDateFormatter setTimeZone:GMTTimezone];

        self.abbreviatedDateFormatter = [[NSDateFormatter alloc] init];
        [self.abbreviatedDateFormatter setDateFormat:@"LLL dd"];
        [self.abbreviatedDateFormatter setTimeZone:GMTTimezone];

        self.monthDayYearFormatter = [[NSDateFormatter alloc] init];
        self.monthDayYearFormatter.dateFormat = @"LLL dd, yyyy";
        self.monthDayYearFormatter.timeZone = GMTTimezone;

        self.dateAndTimeFormatter = [[NSDateFormatter alloc] init];
        [self.dateAndTimeFormatter setDateFormat:@"LLL dd hh:mm a"];
        [self.dateAndTimeFormatter setTimeZone:GMTTimezone];

        self.dateAndWeekdayFormatter = [[NSDateFormatter alloc] init];
        [self.dateAndWeekdayFormatter setDateFormat:@"ccc LLL dd yyyy"];
        [self.dateAndWeekdayFormatter setTimeZone:[NSTimeZone localTimeZone]];
    }
    return self;
}

#pragma mark -

- (NSDate *)dateFromServerString:(NSString*)dateString
{
    return [self dateFromServerString:dateString convertedToLocalTime:NO];
}

- (NSDate *)dateFromServerString:(NSString *)dateString convertedToLocalTime:(BOOL)convertToLocal
{
    // See: https://github.com/mwaterfall/MWFeedParser/blob/master/Classes/NSDate%2BInternetDateTime.m
    NSParameterAssert(dateString);
    if ( dateString == nil )
    {
        return nil;
    }

    NSDate* date = nil;
    NSString *RFC3339String = [[NSString stringWithString:dateString] uppercaseString];
    RFC3339String = [RFC3339String stringByReplacingOccurrencesOfString:@"Z" withString:@"-0000"];
    // Remove colon in timezone as it breaks NSDateFormatter in iOS 4+.
    // - see https://devforums.apple.com/thread/45837
    if (RFC3339String.length > 20) {
        RFC3339String = [RFC3339String stringByReplacingOccurrencesOfString:@":"
                                                                 withString:@""
                                                                    options:0
                                                                      range:NSMakeRange(20, RFC3339String.length-20)];
    }
    
    if (!date) { // 1937-01-01T12:00:27.87+0020
        [self.serverDateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss.SSSZZZ"];
        date = [self.serverDateFormatter dateFromString:RFC3339String];
    }
    if (!date) { // 1996-12-19T16:39:57-0800
        [self.serverDateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZ"];
        date = [self.serverDateFormatter dateFromString:RFC3339String];
    }
    if (!date) { // 1937-01-01T12:00:27
        [self.serverDateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss"];
        date = [self.serverDateFormatter dateFromString:RFC3339String];
    }
    
    if (date == nil)
    {
        NSLog(@"Could not parse RFC3339 date: \"%@\" Possible invalid format.", dateString);
    }
    
    if ( convertToLocal == YES )
    {
        NSTimeInterval intervalToGMT = 0 - [[NSTimeZone localTimeZone] secondsFromGMT];
        date = [date dateByAddingTimeInterval:intervalToGMT];
    }
    return date;
}

- (NSString *)serverDateFromDate:(NSDate *)date
{
    /// @note This a work around, refactoring needed.
    static NSDateFormatter *tempDateFormatter = nil;
    static dispatch_once_t creationPredicate;

    dispatch_once(&creationPredicate, ^{
        tempDateFormatter = [[NSDateFormatter alloc] init];
        tempDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        tempDateFormatter.timeZone = [NSTimeZone localTimeZone];
        tempDateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T00:00:00Z'";
    });
    return [tempDateFormatter stringFromDate:date];
}

- (NSString *)serverDateAndTimeFromDate:(NSDate *)date
{
    /// @note This a work around, refactoring needed.
    static NSDateFormatter *tempDateFormatter = nil;
    static dispatch_once_t creationPredicate;

    dispatch_once(&creationPredicate, ^{
        tempDateFormatter = [[NSDateFormatter alloc] init];
        tempDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        tempDateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        tempDateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'";
    });
    return [tempDateFormatter stringFromDate:date];
}

- (NSString *)abbreviatedStringFromDate:(NSDate*)date convertedToLocalTime:(BOOL)convertToLocal
{
    if ( convertToLocal == NO )
    {
        [self.abbreviatedDateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    }
    else
    {
        /*
         @note: From Apple documentation about systemTimeZone method:
         If you get the system time zone, it is cached by the application and does not change if the user subsequently changes the system time zone. The next time you invoke systemTimeZone, you get back the same time zone you originally got. You have to invoke resetSystemTimeZone to clear the cached object.
         */
        [self.abbreviatedDateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    }
    return [self.abbreviatedDateFormatter stringFromDate:date];
}

- (NSString *)monthDayYearStringFromDate:(NSDate *)date convertedToLocalTime:(BOOL)convertToLocal
{
    self.monthDayYearFormatter.timeZone = ( ( convertToLocal == NO ) ? [NSTimeZone timeZoneForSecondsFromGMT:0] : [NSTimeZone systemTimeZone] );
    return [self.monthDayYearFormatter stringFromDate:date];
}

- (NSString *)dateAndTimeStringFromDate:(NSDate*)date convertedToLocalTime:(BOOL)convertToLocal
{
    if ( convertToLocal == NO )
    {
        [self.dateAndTimeFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    }
    else
    {
        [self.dateAndTimeFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    }
    return [self.dateAndTimeFormatter stringFromDate:date];
}

- (NSString *)recentDateAndTimeStringFromDate:(NSDate *)date convertedToLocalTime:(BOOL)convertToLocal
{
    //@note In order to make the string logic easier, we are not handling cases where the time is 1 Hour/Minute/Second ago. Instead, we display the time in another format.

    NSTimeInterval secondsSinceDate = (-[date timeIntervalSinceNow]);
    if ( secondsSinceDate < kCSDateIntervalToBeConsideredRecent )
    {
        if ( secondsSinceDate >= kCSSecondsInTwoHours )
        {
            // > 2 hours
            NSInteger hours = secondsSinceDate / kCSSecondsInOneHour;
            return [NSString stringWithFormat:NSLocalizedString(@"CSHoursAgo", @"The format for displaying how much time has elapsed in hours."), hours];
        }
        else if ( secondsSinceDate >= kCSSecondsInTwoMinutes )
        {
            // > 2 minutes
            NSInteger minutes = secondsSinceDate / kCSSecondsInOneMinute;
            return [NSString stringWithFormat:NSLocalizedString(@"CSMinutesAgo", @"The format for displaying how much time has elapsed in minutes."), minutes];
        }
        else
        {
            // Prevent against negative values of secondsSinceDate and avoid having to make a special string for "1 second ago"
            secondsSinceDate = MAX(secondsSinceDate, 2);
            return [NSString stringWithFormat:NSLocalizedString(@"CSSecondsAgo", @"The format for displaying how much time has elapsed in seconds."), (NSInteger)secondsSinceDate];
        }
    }
    return [self dateAndTimeStringFromDate:date convertedToLocalTime:convertToLocal];
}

- (NSString *)dateRangeStringStartingOn:(id)startDate endingOn:(id)endDate
{
    NSParameterAssert(startDate);
    NSParameterAssert(endDate);
    
    NSDate* arrivalDate = nil;
    NSDate* departureDate = nil;
    
    if ( [startDate isKindOfClass:[NSString class]] == YES )
    {
        arrivalDate = [self dateFromServerString:startDate];
    }
    else
    {
        NSAssert( [startDate isKindOfClass:[NSDate class]] == YES , @"Should be a NSDate or NSString");
        arrivalDate = startDate;
    }
    if ( [endDate isKindOfClass:[NSString class]] == YES )
    {
        departureDate = [self dateFromServerString:endDate];
    }
    else
    {
        NSAssert( [endDate isKindOfClass:[NSDate class]] == YES , @"Should be a NSDate or NSString");
        departureDate = endDate;
    }
    
    NSString* arrivalDateStringAbrv = [self abbreviatedStringFromDate:arrivalDate convertedToLocalTime:NO];
    NSString* departureDateStringAbrv = [self abbreviatedStringFromDate:departureDate convertedToLocalTime:NO];
    
    // Add the year if the departure date is not in the current year.
    NSDateComponents *currentDateComponents = [[NSCalendar currentCalendar] components:NSYearCalendarUnit
                                                                              fromDate:[NSDate date]];
    NSDateComponents *cellDateComponents = [[NSCalendar currentCalendar] components:NSYearCalendarUnit
                                                                           fromDate:departureDate];
    int yearOfRequest = [cellDateComponents year];
    if ( yearOfRequest == [currentDateComponents year] )
    {
        return [NSString stringWithFormat:@"%@ - %@", arrivalDateStringAbrv, departureDateStringAbrv];
    }
    return [NSString stringWithFormat:@"%@ - %@, %d", arrivalDateStringAbrv, departureDateStringAbrv, yearOfRequest];
}

- (NSString *)dateAndWeekdayStringFromData:(NSDate *)date
{
    return [self.dateAndWeekdayFormatter stringFromDate:date];
}

@end
