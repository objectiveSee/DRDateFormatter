//
//  DRDateFormatter.h
//
//  This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported.
//  To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/
//

/**
 @class DRDateFormatter
 @brief A class useful for converting between various date and time representations. The date format is set during initialization and shoudn't be changed.
 @todo Refactoring needed. The temporary date formatter created in serverDateFromDate and serverDateAndTimeFromDate could be optimized. The WWDC2012 Session 244 Talk mentions date formatting. Some important notes to consider during the refactoring of this class are:
    - Use localizedStringFromDate:dateStyle:timeStyle:
    - Use [dateFormatter setDateStyle:]
    - Use +dateFormateFromTemplate:options:locale:
    - Use strptime_l() for parsing server time.
 */
@interface DRDateFormatter : NSObject

@property (nonatomic, strong, readonly) NSDateFormatter *serverDateFormatter;

//#pragma mark -
+ (id) sharedDateFormatter;

#pragma mark -
/**
 Converts from a date string provided by the server (API) into a NSDate object
 @param string - Server date string
 */
- (NSDate *)dateFromServerString:(NSString *)dateString;

/**
 Converts from a date string provided by the server (API) into a NSDate object and, optionally, handles the converstion to the local time zone. The convertToLocal option is useful if you are working with a date that has no time components (ie. HH:MM:SS is 00:00:00) and you only want to day/month/year of the date. Without converting to local then the date could be off by 1 day.
 @param string - Server date string
 @param convertToLocal If YES then the date is converted into the local time zone. If NO then UTC-0 is used.
 */
- (NSDate *)dateFromServerString:(NSString *)dateString convertedToLocalTime:(BOOL)convertToLocal;

/**
 Returns a date string in the acceptable format that the CouchSurfing server uses. Specifies the date only and not the time.
 @param data The date to create the string from.
 */
- (NSString *)serverDateFromDate:(NSDate *)date;

/**
 Returns a date string in the acceptable format that the CouchSurfing server uses. Specifies the date and time.
 @param data The date to create the string from.
 */
- (NSString *)serverDateAndTimeFromDate:(NSDate *)date;

/**
 Returns an abbreviated string containing the Month and Day from the provided date.
 Example: Apr 22
 @param data The date to create the string from.
 @param convertToLocal If YES then the date is converted into the local time zone. If NO then UTC-0 is used.
 */
- (NSString *)abbreviatedStringFromDate:(NSDate *)date convertedToLocalTime:(BOOL)convertToLocal;

/**
 Returns a string that contains the month, the day and the year of the given date.
 Example: Apr 22, 1985
 @param date The date used to creted the string.
 @param convertToLocal If YES then the date is converted into the local time zone. If NO then UTC is used.
 @return A string that contains the month, the day and the year of the given date.
 */
- (NSString *)monthDayYearStringFromDate:(NSDate *)date convertedToLocalTime:(BOOL)convertToLocal;

/**
 Returns a human readable represention of provided date's date and time.
 Example: Apr 22 04:20 am
 @param data The date to create the string from.
 @param convertToLocal If YES then the date is converted into the local time zone. If NO then UTC is used.
 */
- (NSString *)dateAndTimeStringFromDate:(NSDate *)date convertedToLocalTime:(BOOL)convertToLocal;

/**
 Returns a human readable representation of the provided date's Date. If the date is recently then the date format is displayed using "minutes ago" or "seconds ago", else the same representation as dateAndTimeStringFromDate:convertedToLocalTime: is used.
 @param data The date to create the string from.
 @param convertToLocal If YES then the date is converted into the local time zone. If NO then UTC is used.
 */
- (NSString *)recentDateAndTimeStringFromDate:(NSDate *)date convertedToLocalTime:(BOOL)convertToLocal;

/**
 Returns a human readable representation of the provided date's Date in the format of abbreivated weekday, abbreivated month, day, year. This string is parsable by the white-space " " character.
 Example: Sun Apr 22 2012
 @param data The date to create the string from.
 */
- (NSString *)dateAndWeekdayStringFromData:(NSDate *)date;

/**
 Returns a human readable representation of a date range.
 @note Input can be NSString (server date format) or NSDate
 */
- (NSString *)dateRangeStringStartingOn:(id)startDate endingOn:(id)endDate;

@end
