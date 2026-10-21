"
Unit tests of MGTemporalFormat: ISO 8601 / RFC 3339 printing and parsing of Date, Time, DateAndTime and Duration, as used by the Date, Time, DateTime and Duration GraphQL scalars. MGTemporalFormat never raises: unsupported or invalid input answers nil.
"
Class {
	#name : 'MGTemporalFormatTest',
	#superclass : 'TestCase',
	#category : 'Moose-GraphQL-Tests',
	#package : 'Moose-GraphQL-Tests'
}

{ #category : 'tests - parsing' }
MGTemporalFormatTest >> testParseDate [
	"YYYY-MM-DD only; invalid calendar dates (Feb 30, month 13), short years and garbage answer nil"

	self
		assert: (MGTemporalFormat parseDate: '2017-07-04')
		equals: (Date year: 2017 month: 7 day: 4).
	self
		assert: (MGTemporalFormat parse: '2016-02-29' as: 'Date')
		equals: (Date year: 2016 month: 2 day: 29).
	#( '2017-02-30' '2017-13-01' '17-07-04' '2017-07-04x' ' 2017-07-04'
	   '' '2017-07-04T04:05:06Z' ) do: [ :each |
			self
				assert: (MGTemporalFormat parseDate: each) isNil
				description: each ].
	self assert: (MGTemporalFormat parseDate: 42) isNil.
	self assert: (MGTemporalFormat parseDate: nil) isNil
]

{ #category : 'tests - parsing' }
MGTemporalFormatTest >> testParseDateAndTime [
	"Accepted forms: T, t or space separator; Z, z, ±hh:mm, ±hhmm or no offset (UTC); the given offset is kept"

	| expected parsed |
	expected := DateAndTime
		            year: 2017
		            month: 7
		            day: 4
		            hour: 4
		            minute: 5
		            second: 6
		            offset: Duration zero.
	#( '2017-07-04T04:05:06Z' '2017-07-04t04:05:06z'
	   '2017-07-04 04:05:06+00:00' '2017-07-04T04:05:06'
	   '2017-07-04T04:05:06+0000' ) do: [ :each |
			self
				assert: (MGTemporalFormat parseDateAndTime: each)
				equals: expected ].
	parsed := MGTemporalFormat parseDateAndTime:
		          '2017-07-04T04:05:06+02:00'.
	self assert: parsed offset equals: (Duration hours: 2).
	self assert: parsed hour equals: 4.
	parsed := MGTemporalFormat
		          parse: '2017-07-04T04:05:06-0530'
		          as: 'DateTime'.
	self assert: parsed offset equals: (Duration minutes: -330).
	self
		assert: (MGTemporalFormat print: parsed)
		equals: '2017-07-04T04:05:06-05:30'.
	self
		assert:
			(MGTemporalFormat print: (MGTemporalFormat parseDateAndTime:
					  '2017-07-04T04:05:06.123456789+02:00'))
		equals: '2017-07-04T04:05:06.123+02:00'
]

{ #category : 'tests - parsing' }
MGTemporalFormatTest >> testParseDateAndTimeRejections [
	"Invalid dates or times, out-of-range offsets, a missing time, and leading or trailing garbage answer nil"

	#( '2017-02-30T04:05:06Z' '2017-07-04T24:00:00Z'
	   '2017-07-04T04:05:06+25:00' '2017-07-04' ' 2017-07-04T04:05:06Z'
	   '2017-07-04T04:05:06Zx' '2017-07-04X04:05:06Z'
	   '' ) do: [ :each |
			self
				assert: (MGTemporalFormat parseDateAndTime: each) isNil
				description: each ].
	self assert: (MGTemporalFormat parseDateAndTime: 42) isNil
]

{ #category : 'tests - parsing' }
MGTemporalFormatTest >> testParseDuration [
	"[-]P[nW][nD][T[nH][nM][n[.f]S]]; empty P / PT, years, months, fractions on other units than seconds, out-of-order designators, lowercase designators and garbage answer nil"

	self
		assert: (MGTemporalFormat parseDuration: 'PT0S')
		equals: Duration zero.
	self
		assert: (MGTemporalFormat parseDuration: 'PT2M5S')
		equals: (Duration
				 days: 0
				 hours: 0
				 minutes: 2
				 seconds: 5).
	self
		assert: (MGTemporalFormat parse: 'P1DT2H3M4.5S' as: 'Duration')
		equals: (Duration
				 days: 1
				 hours: 2
				 minutes: 3
				 seconds: 4) + (Duration milliSeconds: 500).
	self
		assert: (MGTemporalFormat parseDuration: '-PT5S')
		equals: (Duration seconds: -5).
	self
		assert: (MGTemporalFormat parseDuration: 'P1W2D')
		equals: (Duration days: 9).
	#( 'P' 'PT' 'P1Y' 'P1M' 'PT1.5H' 'PT1.5M' 'PT5S3M' 'PT5Sx' 'xPT5S'
	   'pt5s' '' '5S' ) do: [ :each |
			self
				assert: (MGTemporalFormat parseDuration: each) isNil
				description: each ].
	self assert: (MGTemporalFormat parseDuration: 5) isNil
]

{ #category : 'tests - parsing' }
MGTemporalFormatTest >> testParseTime [
	"hh:mm[:ss[.f+]] 24h; 24:00, minute 60, single-digit hours, a dangling dot and trailing spaces answer nil"

	self
		assert: (MGTemporalFormat parseTime: '04:05:06')
		equals: (Time hour: 4 minute: 5 second: 6).
	self
		assert: (MGTemporalFormat parseTime: '04:05')
		equals: (Time hour: 4 minute: 5 second: 0).
	self
		assert: (MGTemporalFormat parse: '16:05:06.25' as: 'Time')
		equals: (Time
				 hour: 16
				 minute: 5
				 second: 6
				 nanoSecond: 250000000).
	#( '24:00' '24:00:00' '23:60' '4:05' '04:05:06 ' '04:05:06.'
	   'x04:05' ) do: [ :each |
			self
				assert: (MGTemporalFormat parseTime: each) isNil
				description: each ]
]

{ #category : 'tests - printing' }
MGTemporalFormatTest >> testPrintDate [
	"Dates print as YYYY-MM-DD; years outside 0-9999 cannot be written with 4 digits and answer nil"

	self
		assert: (MGTemporalFormat print: (Date year: 2017 month: 7 day: 4))
		equals: '2017-07-04'.
	self
		assert:
		(MGTemporalFormat printDate: (Date year: 5 month: 12 day: 31))
		equals: '0005-12-31'.
	self assert:
		(MGTemporalFormat print: (Date year: 10000 month: 1 day: 1)) isNil.
	self assert:
		(MGTemporalFormat print: (Date year: -1 month: 1 day: 1)) isNil
]

{ #category : 'tests - printing' }
MGTemporalFormatTest >> testPrintDateAndTime [
	"DateAndTimes print as YYYY-MM-DDThh:mm:ss[.fff]±hh:mm keeping their own offset (not converted to UTC); a zero offset prints +00:00"

	self
		assert: (MGTemporalFormat print: (DateAndTime
					  year: 2017
					  month: 7
					  day: 4
					  hour: 4
					  minute: 5
					  second: 6
					  offset: (Duration hours: 2)))
		equals: '2017-07-04T04:05:06+02:00'.
	self
		assert: (MGTemporalFormat print: (DateAndTime
					  year: 2017
					  month: 7
					  day: 4
					  hour: 23
					  minute: 5
					  second: 6
					  offset: (Duration minutes: -330)))
		equals: '2017-07-04T23:05:06-05:30'.
	self
		assert: (MGTemporalFormat printDateAndTime: (DateAndTime
					  year: 2017
					  month: 7
					  day: 4
					  hour: 4
					  minute: 5
					  second: 6
					  offset: Duration zero))
		equals: '2017-07-04T04:05:06+00:00'.
	"fraction truncated to milliseconds"
	self
		assert: (MGTemporalFormat print: (DateAndTime
					  year: 2017
					  month: 7
					  day: 4
					  hour: 4
					  minute: 5
					  second: 6
					  nanoSecond: 123456789
					  offset: Duration zero))
		equals: '2017-07-04T04:05:06.123+00:00'.
	self assert: (MGTemporalFormat print: (DateAndTime
				  year: 10000
				  month: 1
				  day: 1
				  hour: 0
				  minute: 0
				  second: 0
				  offset: Duration zero)) isNil
]

{ #category : 'tests - printing' }
MGTemporalFormatTest >> testPrintDuration [
	"Durations print in ISO 8601 with days, hours, minutes and seconds only, zero components omitted, a leading minus when negative, PT0S when zero"

	self assert: (MGTemporalFormat print: Duration zero) equals: 'PT0S'.
	self
		assert: (MGTemporalFormat print: (Duration
					  days: 0
					  hours: 0
					  minutes: 2
					  seconds: 5))
		equals: 'PT2M5S'.
	self
		assert: (MGTemporalFormat printDuration: (Duration
					  days: 1
					  hours: 2
					  minutes: 3
					  seconds: 4) + (Duration milliSeconds: 500))
		equals: 'P1DT2H3M4.5S'.
	self
		assert: (MGTemporalFormat print: (Duration seconds: -5))
		equals: '-PT5S'.
	self
		assert: (MGTemporalFormat print: (Duration milliSeconds: -1500))
		equals: '-PT1.5S'.
	self
		assert: (MGTemporalFormat print: (Duration days: 2))
		equals: 'P2D'.
	self
		assert: (MGTemporalFormat print: (Duration hours: 1))
		equals: 'PT1H'
]

{ #category : 'tests - printing' }
MGTemporalFormatTest >> testPrintNonTemporalAnswersNil [
	"Non temporal values, and values of another temporal kind than the one asked, answer nil without raising"

	#( 42 'x' nil #sym ) do: [ :each |
		self assert: (MGTemporalFormat print: each) isNil ].
	self assert: (MGTemporalFormat print: Month current) isNil.
	self assert: (MGTemporalFormat print: Object new) isNil.
	self assert:
		(MGTemporalFormat printDate: (Time hour: 1 minute: 2 second: 3))
			isNil.
	self assert:
		(MGTemporalFormat printTime: (Date year: 2017 month: 7 day: 4))
			isNil.
	self assert:
		(MGTemporalFormat printDateAndTime:
			 (Date year: 2017 month: 7 day: 4)) isNil.
	self assert: (MGTemporalFormat printDuration: 5) isNil
]

{ #category : 'tests - printing' }
MGTemporalFormatTest >> testPrintTime [
	"Times print as hh:mm:ss (24h) with an optional fraction truncated to milliseconds, omitted when zero, without trailing zeros"

	self
		assert: (MGTemporalFormat print: (Time hour: 4 minute: 5 second: 6))
		equals: '04:05:06'.
	self
		assert:
		(MGTemporalFormat printTime: (Time hour: 16 minute: 5 second: 6))
		equals: '16:05:06'.
	self
		assert: (MGTemporalFormat print: (Time
					  hour: 16
					  minute: 5
					  second: 6
					  nanoSecond: 250000000))
		equals: '16:05:06.25'.
	self
		assert: (MGTemporalFormat print: (Time
					  hour: 16
					  minute: 5
					  second: 6
					  nanoSecond: 123000000))
		equals: '16:05:06.123'.
	"truncated, never rounded up to the next second"
	self
		assert: (MGTemporalFormat print: (Time
					  hour: 16
					  minute: 5
					  second: 6
					  nanoSecond: 999999999))
		equals: '16:05:06.999'
]

{ #category : 'tests - parsing' }
MGTemporalFormatTest >> testRoundTrips [
	"Printing then parsing answers an equal value for every temporal kind (at millisecond precision)"

	{
		(Date year: 2017 month: 7 day: 4).
		(Time
			 hour: 16
			 minute: 5
			 second: 6
			 nanoSecond: 250000000).
		(DateAndTime
			 year: 2017
			 month: 7
			 day: 4
			 hour: 4
			 minute: 5
			 second: 6
			 nanoSecond: 123000000
			 offset: (Duration hours: -7)).
		(Duration
			 days: 1
			 hours: 2
			 minutes: 3
			 seconds: 4).
		(Duration seconds: -5).
		Duration zero } do: [ :each |
			| printed |
			printed := MGTemporalFormat print: each.
			self
				assert: (MGTemporalFormat
						 parse: printed
						 as: (MGTemporalFormat scalarNameOf: each))
				equals: each.
			self
				assert: (MGTemporalFormat print: (MGTemporalFormat
							  parse: printed
							  as: (MGTemporalFormat scalarNameOf: each)))
				equals: printed ].
	"an unknown scalar name or a non-String answers nil"
	self assert: (MGTemporalFormat parse: '2017-07-04' as: 'Foo') isNil.
	self assert: (MGTemporalFormat parse: nil as: 'Date') isNil
]

{ #category : 'tests - kinds' }
MGTemporalFormatTest >> testScalarNameOf [
	"Each temporal class maps to its GraphQL scalar; Month (a Timespan, like Date) and other objects map to nil"

	self
		assert:
		(MGTemporalFormat scalarNameOf: (Date year: 2017 month: 7 day: 4))
		equals: 'Date'.
	self
		assert:
		(MGTemporalFormat scalarNameOf: (Time hour: 4 minute: 5 second: 6))
		equals: 'Time'.
	self
		assert: (MGTemporalFormat scalarNameOf: DateAndTime now)
		equals: 'DateTime'.
	self
		assert: (MGTemporalFormat scalarNameOf: (Duration seconds: 5))
		equals: 'Duration'.
	self assert: (MGTemporalFormat scalarNameOf: Month current) isNil.
	self assert: (MGTemporalFormat scalarNameOf: 42) isNil.
	self assert: (MGTemporalFormat scalarNameOf: nil) isNil.
	self assert: (MGTemporalFormat isTemporal: (Duration seconds: 5)).
	self deny: (MGTemporalFormat isTemporal: Month current).
	self deny: (MGTemporalFormat isTemporal: '2017-07-04').
	self
		assert: MGTemporalFormat temporalScalarNames asSet
		equals: #( 'Date' 'Time' 'DateTime' 'Duration' ) asSet
]
