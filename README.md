DRDateFormatter
===============

A class useful for converting between local date and time representations and UTC+0 dates using RFC 3339 format.

Servers should always use the UTC+0 timezone and represent their dates using the RFC 3339 format. This class provides a singleton that can convert between NSString and NSDate representation of RFC339 dates. It also lets you convert dates into the local time zone.

## Installation

### Cocoapods

```ruby
pod 'DRDateFormatter', '~> 1.0.0'
```

## Usage

See DRDateFormatter.h for full documentation.

```objective-c

NSString *dateString = @"2002-10-02T10:00:00-05:00";
NSDate *date = [[DRDateFormatter sharedDateFormatter] dateFromServerString:dateString convertedToLocalTime:YES];

```

Also supports recent time representations such as "2 hours ago". See **DRDateFormatter.h** for full documentation.

```objective-c

/**
Returns a human readable representation of the provided date's Date. If the date is recently then the date format is displayed using "minutes ago" or "seconds ago", else the same representation as dateAndTimeStringFromDate:convertedToLocalTime: is used.
*/
- (NSString *)recentDateAndTimeStringFromDate:(NSDate *)date convertedToLocalTime:(BOOL)convertToLocal;

```

## RFC 3339

See http://tools.ietf.org/html/rfc3339

## Authors

This project was created by Danny Ricciotti
GitHub: @objectiveSee
Twitter: @topwobble

## License

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/. 
